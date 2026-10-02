import { DailyReelExperienceConfigSchema } from "./dailyReelSchema.js";
import type { DailyReelChallengeSessionGateway } from "./dailyReelChallenges.js";
import type { DailyReelSecurity } from "./dailyReelSecurity.js";
import {
  DailyReelSessionError,
  type DailyReelSessionStore,
  type DailyReelSessionService,
} from "./dailyReelSessions.js";

export class SessionBackedDailyReelChallengeGateway implements DailyReelChallengeSessionGateway {
  constructor(
    private readonly sessions: DailyReelSessionStore,
    private readonly service: DailyReelSessionService,
    private readonly security: DailyReelSecurity,
  ) {}

  async getCompletedSession(input: { capability: string; anonymousIdHash: string }) {
    const record = await this.sessions.get(this.security.hashCapability(input.capability));
    if (!record || record.anonymousIdHash !== input.anonymousIdHash || record.status !== "completed" || !record.completedAt) {
      return null;
    }
    return {
      sessionId: record.sessionId,
      anonymousIdHash: record.anonymousIdHash,
      publicationId: record.publicationId,
      versionId: record.versionId,
      locale: record.locale,
      totalScore: record.totalScore,
      completedAt: Date.parse(record.completedAt),
      experienceConfig: structuredClone(record.config) as Record<string, unknown>,
      experienceConfigHash: record.config.configId,
    };
  }

  async startChallengeSession(input: {
    anonymousId: string;
    publicationId: string;
    versionId: string;
    locale: string;
    challengeId: string;
    experienceConfig: Readonly<Record<string, unknown>>;
    experienceConfigHash: string;
    expiresAt: number;
  }) {
    const config = DailyReelExperienceConfigSchema.parse(input.experienceConfig);
    if (config.configId !== input.experienceConfigHash) {
      throw new DailyReelSessionError("challenge.config_mismatch", "Challenge configuration is invalid");
    }
    const started = await this.service.start({
      anonymousId: input.anonymousId,
      publicationId: input.publicationId,
      locale: input.locale,
      mode: "challenge",
      scopeId: input.challengeId,
      experienceResolution: {
        eligible: true,
        config,
        configId: config.configId,
        assignmentSource: "challenge",
        variants: { rollout: "challenge" },
      },
    });
    if (started.session.contentVersion !== input.versionId) {
      throw new DailyReelSessionError("challenge.content_mismatch", "Challenge content is no longer available");
    }
    return { sessionId: started.session.sessionId, capability: started.capability };
  }

  async getSessionOutcome(input: { sessionId: string; capabilityHash: string }) {
    const record = await this.sessions.get(input.capabilityHash);
    if (!record || record.sessionId !== input.sessionId) {
      throw new DailyReelSessionError("session.not_found", "Challenge session was not found");
    }
    return record.status === "completed" && record.completedAt
      ? { completed: true, totalScore: record.totalScore, completedAt: Date.parse(record.completedAt) }
      : { completed: false };
  }
}
