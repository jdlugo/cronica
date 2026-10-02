import { getApps, initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { getMessaging } from "firebase-admin/messaging";
import { defineSecret } from "firebase-functions/params";
import { logger } from "firebase-functions/v2";
import { onRequest } from "firebase-functions/v2/https";
import { onSchedule } from "firebase-functions/v2/scheduler";

import { normalizeDailyPuzzleAdminConfig } from "./adminConfig.js";
import { isPastPrimaryGenerationWindow, resolveScheduleTargetDate } from "./coverageSchedule.js";
import {
  loadRandomPuzzleDocument,
  loadPuzzleByDate,
  loadRecentPuzzleTmdbIDs,
  persistPuzzleDocument
} from "./firestoreRepository.js";
import { formatPushBodyFromEmojiClue, generateDailyPuzzleDocument } from "./generator.js";
import {
  handleGetLatestDailyPuzzle,
  handleGetRandomDailyPuzzle,
  handleSendDailyPuzzleTestPush,
  handleUpdateDailyPuzzleAdminConfig
} from "./handlers.js";
import { OpenAiStructuredPuzzleGenerator } from "./openaiClient.js";
import { runDailyPuzzlePipeline } from "./pipeline.js";
import type { DailyPuzzleDocument } from "./puzzleSchema.js";
import { fetchCandidateWithExclusionFallback } from "./schedulerUtils.js";
import { fetchTmdbCandidate, fetchTmdbLocalizations } from "./tmdb.js";
import { makeProductionDailyReelAPI } from "./dailyReelProduction.js";
import {
  DailyReelCoverageService,
  DailyReelNoApprovedPublicationError,
  FirestoreDailyReelCoverageStore,
} from "./dailyReelCoverage.js";

const tmdbApiKeySecret = defineSecret("TMDB_API_KEY");
const openAiApiKeySecret = defineSecret("OPENAI_API_KEY");
const dailyPuzzleAdminKeySecret = defineSecret("DAILY_PUZZLE_ADMIN_KEY");
const dailyReelCapabilitySecret = defineSecret("DAILY_REEL_CAPABILITY_SECRET");
const posthogProjectTokenSecret = defineSecret("POSTHOG_PROJECT_TOKEN");
const dailyReelShareBaseUrlSecret = defineSecret("DAILY_REEL_SHARE_BASE_URL");

if (getApps().length === 0) {
  initializeApp();
}

async function loadAdminConfig() {
  try {
    const db = getFirestore();
    const snapshot = await db.collection("adminSettings").doc("dailyPuzzle").get();
    return normalizeDailyPuzzleAdminConfig(snapshot.data());
  } catch (error) {
    logger.error("Unable to load adminSettings/dailyPuzzle. Falling back to defaults.", error);
    return normalizeDailyPuzzleAdminConfig(undefined);
  }
}

interface ScheduledPipelineOptions {
  sendPushWhenPuzzleExists?: boolean;
}

async function runScheduledDailyPuzzlePipeline(
  targetDate: Date,
  options: ScheduledPipelineOptions = {}
): Promise<void> {
  const tmdbApiKey = tmdbApiKeySecret.value();
  const openAiApiKey = openAiApiKeySecret.value();

  if (!tmdbApiKey) {
    throw new Error("Missing TMDB_API_KEY secret value");
  }

  if (!openAiApiKey) {
    throw new Error("Missing OPENAI_API_KEY secret value");
  }

  const aiGenerator = new OpenAiStructuredPuzzleGenerator(openAiApiKey);
  await runDailyPuzzlePipeline({
    targetDate,
    loadAdminConfig,
    loadExistingPuzzle: async (taskDate) => loadPuzzleByDate(getFirestore(), taskDate),
    sendPushWhenPuzzleExists: options.sendPushWhenPuzzleExists ?? false,
    syncLatestPuzzleFromExisting: async (existingPuzzle) => {
      if (!(options.sendPushWhenPuzzleExists ?? false)) {
        return;
      }
      await getFirestore()
        .collection("dailyPuzzles")
        .doc("latest")
        .set({ ...existingPuzzle, updated_at: new Date().toISOString() }, { merge: true });
    },
    generatePuzzle: async (taskDate) =>
      generateDailyPuzzleDocument({
        targetDate: taskDate,
        tmdbFetcher: async () => {
          const excludedTmdbIDs = await loadRecentPuzzleTmdbIDs(getFirestore(), taskDate);
          return fetchCandidateWithExclusionFallback({
            excludedTmdbIDs,
            fetchWithExclusions: (excludeTmdbIDs) =>
              fetchTmdbCandidate({
                apiKey: tmdbApiKey,
                targetDate: taskDate,
                excludeTmdbIDs
              }),
            fetchWithoutExclusions: () =>
              fetchTmdbCandidate({
                apiKey: tmdbApiKey,
                targetDate: taskDate
              }),
            logger
          });
        },
        localizationFetcher: async (movie) =>
          fetchTmdbLocalizations({
            apiKey: tmdbApiKey,
            movie
          }),
        aiGenerator
      }),
    persistPuzzle: async (puzzle) => persistPuzzleDocument(getFirestore(), puzzle),
    sendPush: async (puzzle, pushBody) => {
      await getMessaging().send({
        topic: "daily-puzzle",
        notification: {
          title: "Daily Puzzle 🎬",
          body: pushBody
        },
        data: {
          type: "daily_puzzle",
          puzzle_id: puzzle.puzzle_id,
          puzzle_date: puzzle.date
        }
      });
    },
    formatPushBody: formatPushBodyFromEmojiClue,
    logger
  });
}

export const generateDailyPuzzle = onSchedule(
  {
    schedule: "5 5 * * *",
    timeZone: "Etc/UTC",
    secrets: [tmdbApiKeySecret, openAiApiKeySecret]
  },
  async (event) => {
    const targetDate = resolveScheduleTargetDate(event.scheduleTime);
    await runScheduledDailyPuzzlePipeline(targetDate, {
      sendPushWhenPuzzleExists: true
    });
  }
);

export const ensureDailyPuzzleCoverage = onSchedule(
  {
    schedule: "17 * * * *",
    timeZone: "Etc/UTC",
    secrets: [tmdbApiKeySecret, openAiApiKeySecret]
  },
  async (event) => {
    const targetDate = resolveScheduleTargetDate(event.scheduleTime);
    if (!isPastPrimaryGenerationWindow(targetDate)) {
      logger.info("Skipping coverage run before primary generation window.", {
        targetDate: targetDate.toISOString()
      });
      return;
    }
    await runScheduledDailyPuzzlePipeline(targetDate);
  }
);

async function publishScheduledDailyReel(scheduleTime: string): Promise<void> {
  const publicationId = new Date(scheduleTime).toISOString().slice(0, 10);
  try {
    const publication = await new DailyReelCoverageService(
      new FirestoreDailyReelCoverageStore(getFirestore()),
    ).publish(publicationId);
    logger.info("Daily Reel publication is ready", publication);
  } catch (error) {
    if (error instanceof DailyReelNoApprovedPublicationError) {
      logger.warn("Daily Reel has no approved content for this publication", { publicationId });
      return;
    }
    throw error;
  }
}

export const publishDailyReel = onSchedule(
  {
    schedule: "7 5 * * *",
    timeZone: "Etc/UTC",
  },
  async (event) => publishScheduledDailyReel(event.scheduleTime),
);

export const ensureDailyReelPublished = onSchedule(
  {
    schedule: "29 * * * *",
    timeZone: "Etc/UTC",
  },
  async (event) => {
    const scheduledAt = new Date(event.scheduleTime);
    if (scheduledAt.getUTCHours() < 5) {
      logger.info("Skipping Daily Reel recovery before its 05:00 UTC publication window", {
        scheduleTime: event.scheduleTime,
      });
      return;
    }
    await publishScheduledDailyReel(event.scheduleTime);
  },
);

export const getLatestDailyPuzzle = onRequest({ cors: true }, async (_request, response) => {
  await handleGetLatestDailyPuzzle({
    loadLatestPuzzle: async () => {
      const db = getFirestore();
      const latestSnapshot = await db.collection("dailyPuzzles").doc("latest").get();
      if (!latestSnapshot.exists) {
        return null;
      }
      return latestSnapshot.data();
    },
    response,
    logger
  });
});

export const getRandomDailyPuzzle = onRequest({ cors: true }, async (_request, response) => {
  await handleGetRandomDailyPuzzle({
    loadRandomPuzzle: async () => loadRandomPuzzleDocument(getFirestore()),
    response,
    logger
  });
});

export const updateDailyPuzzleAdminConfig = onRequest(
  { cors: true, secrets: [dailyPuzzleAdminKeySecret] },
  async (request, response) => {
    await handleUpdateDailyPuzzleAdminConfig({
      request,
      response,
      logger,
      adminKey: dailyPuzzleAdminKeySecret.value(),
      loadCurrentAdminConfig: loadAdminConfig,
      saveAdminConfig: async (config) => {
        const db = getFirestore();
        await db
          .collection("adminSettings")
          .doc("dailyPuzzle")
          .set({ ...config, updated_at: new Date().toISOString() }, { merge: true });
      }
    });
  }
);

export const sendDailyPuzzleTestPush = onRequest(
  { cors: true, secrets: [dailyPuzzleAdminKeySecret] },
  async (request, response) => {
    await handleSendDailyPuzzleTestPush({
      request,
      response,
      logger,
      adminKey: dailyPuzzleAdminKeySecret.value(),
      loadLatestPuzzle: async () => {
        const db = getFirestore();
        const latestSnapshot = await db.collection("dailyPuzzles").doc("latest").get();
        if (!latestSnapshot.exists) {
          return null;
        }
        return latestSnapshot.data() as DailyPuzzleDocument;
      },
      formatPushBody: formatPushBodyFromEmojiClue,
      sendPush: async (puzzle, pushBody) => {
        await getMessaging().send({
          topic: "daily-puzzle",
          notification: {
            title: "Daily Puzzle 🎬 (Test)",
            body: pushBody
          },
          data: {
            type: "daily_puzzle",
            puzzle_id: puzzle.puzzle_id,
            puzzle_date: puzzle.date,
            is_test_push: "true"
          }
        });
      }
    });
  }
);

export const dailyReelAPI = onRequest(
  {
    cors: true,
    secrets: [dailyReelCapabilitySecret, posthogProjectTokenSecret, dailyReelShareBaseUrlSecret],
  },
  async (request, response) => {
    const capabilitySecret = dailyReelCapabilitySecret.value();
    const posthogProjectToken = posthogProjectTokenSecret.value();
    const shareBaseUrl = dailyReelShareBaseUrlSecret.value();
    if (!capabilitySecret || !posthogProjectToken || !shareBaseUrl) {
      response.status(503).json({ code: "configuration_unavailable", message: "Daily Reel is not configured" });
      return;
    }
    const api = makeProductionDailyReelAPI({
      firestore: getFirestore(),
      capabilitySecret,
      posthogProjectToken,
      shareBaseUrl,
      allowedAppIds: new Set([
        "1:315021799865:ios:9e65997f70fa7e37",
        "1:315021799865:web:87aad9db62c09193a54668",
      ]),
      onInternalError: (error) => logger.error("Daily Reel request failed", error),
    });
    await api.handle(request, response);
  },
);
