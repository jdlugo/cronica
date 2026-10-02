import type { DailyPuzzleAdminConfig } from "./adminConfig.js";
import type { DailyPuzzleDocument } from "./puzzleSchema.js";

interface LoggerLike {
  info: (message: string, metadata?: unknown) => void;
  error: (message: string, metadata?: unknown) => void;
}

export interface DailyPuzzlePushPayload {
  date: string;
  puzzle_id: string;
  emoji_clue: string;
}

interface GenerateDailyPuzzleTaskInput {
  targetDate: Date;
  loadAdminConfig: () => Promise<DailyPuzzleAdminConfig>;
  loadExistingPuzzle?: (targetDate: Date) => Promise<unknown | null>;
  sendPushWhenPuzzleExists?: boolean;
  syncLatestPuzzleFromExisting?: (
    existingPuzzle: Record<string, unknown>
  ) => Promise<void> | void;
  generatePuzzle: (targetDate: Date) => Promise<DailyPuzzleDocument>;
  persistPuzzle: (puzzle: DailyPuzzleDocument) => Promise<boolean | void>;
  sendPush: (puzzle: DailyPuzzlePushPayload, pushBody: string) => Promise<void>;
  formatPushBody: (emojiClue: string) => string;
  logger: LoggerLike;
}

const dayStampPattern = /^\d{4}-\d{2}-\d{2}$/;

function dayStamp(date: Date): string {
  return date.toISOString().slice(0, 10);
}

function normalizeExistingPuzzleForPush(
  existingPuzzle: unknown,
  targetDate: Date
): DailyPuzzlePushPayload | null {
  if (!existingPuzzle || typeof existingPuzzle !== "object") {
    return null;
  }

  const source = existingPuzzle as Record<string, unknown>;
  const date = typeof source.date === "string" ? source.date : dayStamp(targetDate);
  const puzzleID = typeof source.puzzle_id === "string" ? source.puzzle_id : date;
  const emojiClue = typeof source.emoji_clue === "string" ? source.emoji_clue : "";

  if (!dayStampPattern.test(date) || !dayStampPattern.test(puzzleID) || emojiClue.trim().length === 0) {
    return null;
  }

  return {
    date,
    puzzle_id: puzzleID,
    emoji_clue: emojiClue
  };
}

export async function runGenerateDailyPuzzleTask(
  input: GenerateDailyPuzzleTaskInput
): Promise<{ generated: boolean; pushSent: boolean }> {
  const adminConfig = await input.loadAdminConfig();
  if (!adminConfig.enabled) {
    input.logger.info("Daily puzzle generation is disabled by adminSettings/dailyPuzzle.enabled");
    return { generated: false, pushSent: false };
  }

  if (input.loadExistingPuzzle) {
    const existingPuzzle = await input.loadExistingPuzzle(input.targetDate);
    if (existingPuzzle) {
      if (!input.sendPushWhenPuzzleExists) {
        input.logger.info("Daily puzzle already exists for target date. Skipping generation.");
        return { generated: false, pushSent: false };
      }

      if (!adminConfig.pushEnabled) {
        input.logger.info("Daily puzzle push is disabled by adminSettings/dailyPuzzle.pushEnabled");
        return { generated: false, pushSent: false };
      }

      const pushPuzzle = normalizeExistingPuzzleForPush(existingPuzzle, input.targetDate);
      if (!pushPuzzle) {
        input.logger.error(
          "Daily puzzle exists but is missing required push fields. Skipping scheduled push.",
          { targetDate: dayStamp(input.targetDate) }
        );
        return { generated: false, pushSent: false };
      }

      const pushBody = input.formatPushBody(pushPuzzle.emoji_clue);
      input.logger.info("Daily puzzle already exists for target date. Skipping generation.");
      input.logger.info(
        "Daily puzzle already exists for target date. Sending scheduled push for existing puzzle.",
        { puzzleID: pushPuzzle.puzzle_id }
      );

      if (input.syncLatestPuzzleFromExisting && typeof existingPuzzle === "object" && existingPuzzle != null) {
        try {
          await input.syncLatestPuzzleFromExisting(existingPuzzle as Record<string, unknown>);
        } catch (error) {
          input.logger.error("Failed to sync latest daily puzzle alias from existing puzzle", error);
        }
      }

      try {
        await input.sendPush(pushPuzzle, pushBody);
        return { generated: false, pushSent: true };
      } catch (error) {
        input.logger.error("Existing puzzle found but push notification failed", error);
        return { generated: false, pushSent: false };
      }
    }
  }

  const puzzle = await input.generatePuzzle(input.targetDate);
  const persisted = await input.persistPuzzle(puzzle);
  if (persisted === false) {
    input.logger.info("Daily puzzle persistence skipped because puzzle already exists.");
    return { generated: false, pushSent: false };
  }

  if (!adminConfig.pushEnabled) {
    input.logger.info("Daily puzzle push is disabled by adminSettings/dailyPuzzle.pushEnabled");
    return { generated: true, pushSent: false };
  }

  const pushBody = input.formatPushBody(puzzle.emoji_clue);

  try {
    await input.sendPush(puzzle, pushBody);
    return { generated: true, pushSent: true };
  } catch (error) {
    input.logger.error("Puzzle generated but push notification failed", error);
    return { generated: true, pushSent: false };
  }
}

interface HttpResponseLike {
  status: (code: number) => HttpResponseLike;
  json: (body: unknown) => void;
}

interface HttpRequestLike {
  headers?: Record<string, unknown>;
  body?: unknown;
}

interface GetLatestDailyPuzzleInput {
  loadLatestPuzzle: () => Promise<unknown | null>;
  response: HttpResponseLike;
  logger: LoggerLike;
}

export async function handleGetLatestDailyPuzzle(input: GetLatestDailyPuzzleInput): Promise<void> {
  try {
    const latestPuzzle = await input.loadLatestPuzzle();
    if (!latestPuzzle) {
      input.response.status(404).json({ error: "Latest puzzle not found" });
      return;
    }

    input.response.status(200).json(latestPuzzle);
  } catch (error) {
    input.logger.error("Failed to fetch latest daily puzzle", error);
    input.response.status(500).json({ error: "Failed to fetch latest daily puzzle" });
  }
}

interface GetRandomDailyPuzzleInput {
  loadRandomPuzzle: () => Promise<unknown | null>;
  response: HttpResponseLike;
  logger: LoggerLike;
}

export async function handleGetRandomDailyPuzzle(input: GetRandomDailyPuzzleInput): Promise<void> {
  try {
    const randomPuzzle = await input.loadRandomPuzzle();
    if (!randomPuzzle) {
      input.response.status(404).json({ error: "Random puzzle not found" });
      return;
    }

    input.response.status(200).json(randomPuzzle);
  } catch (error) {
    input.logger.error("Failed to fetch random daily puzzle", error);
    input.response.status(500).json({ error: "Failed to fetch random daily puzzle" });
  }
}

interface UpdateDailyPuzzleAdminConfigInput {
  request: HttpRequestLike;
  response: HttpResponseLike;
  logger: LoggerLike;
  adminKey: string;
  loadCurrentAdminConfig: () => Promise<DailyPuzzleAdminConfig>;
  saveAdminConfig: (config: DailyPuzzleAdminConfig) => Promise<void>;
}

function normalizeHeaderValue(value: unknown): string {
  if (typeof value === "string") {
    return value;
  }
  if (Array.isArray(value) && typeof value[0] === "string") {
    return value[0];
  }
  return "";
}

export async function handleUpdateDailyPuzzleAdminConfig(
  input: UpdateDailyPuzzleAdminConfigInput
): Promise<void> {
  if (!input.adminKey) {
    input.response.status(500).json({ error: "Admin key is not configured" });
    return;
  }

  const providedAdminKey = normalizeHeaderValue(input.request.headers?.["x-admin-key"]);
  if (providedAdminKey != input.adminKey) {
    input.response.status(401).json({ error: "Unauthorized" });
    return;
  }

  const body =
    typeof input.request.body === "object" && input.request.body != null
      ? (input.request.body as Record<string, unknown>)
      : {};

  const enabled = typeof body.enabled === "boolean" ? body.enabled : undefined;
  const pushEnabled = typeof body.pushEnabled === "boolean" ? body.pushEnabled : undefined;

  if (enabled === undefined && pushEnabled === undefined) {
    input.response.status(400).json({
      error: "Provide at least one boolean field: enabled, pushEnabled"
    });
    return;
  }

  try {
    const currentConfig = await input.loadCurrentAdminConfig();
    const nextConfig: DailyPuzzleAdminConfig = {
      enabled: enabled ?? currentConfig.enabled,
      pushEnabled: pushEnabled ?? currentConfig.pushEnabled
    };
    await input.saveAdminConfig(nextConfig);
    input.response.status(200).json(nextConfig);
  } catch (error) {
    input.logger.error("Failed to update daily puzzle admin config", error);
    input.response.status(500).json({ error: "Failed to update admin config" });
  }
}

interface SendDailyPuzzleTestPushInput {
  request: HttpRequestLike;
  response: HttpResponseLike;
  logger: LoggerLike;
  adminKey: string;
  loadLatestPuzzle: () => Promise<DailyPuzzleDocument | null>;
  formatPushBody: (emojiClue: string) => string;
  sendPush: (puzzle: DailyPuzzlePushPayload, pushBody: string) => Promise<void>;
}

export async function handleSendDailyPuzzleTestPush(
  input: SendDailyPuzzleTestPushInput
): Promise<void> {
  if (!input.adminKey) {
    input.response.status(500).json({ error: "Admin key is not configured" });
    return;
  }

  const providedAdminKey = normalizeHeaderValue(input.request.headers?.["x-admin-key"]);
  if (providedAdminKey != input.adminKey) {
    input.response.status(401).json({ error: "Unauthorized" });
    return;
  }

  try {
    const latestPuzzle = await input.loadLatestPuzzle();
    if (!latestPuzzle) {
      input.response.status(404).json({ error: "Latest puzzle not found" });
      return;
    }

    const pushBody = input.formatPushBody(latestPuzzle.emoji_clue);
    await input.sendPush(latestPuzzle, pushBody);
    input.response.status(200).json({ ok: true, puzzle_id: latestPuzzle.puzzle_id });
  } catch (error) {
    input.logger.error("Failed to send daily puzzle test push", error);
    input.response.status(500).json({ error: "Failed to send test push" });
  }
}
