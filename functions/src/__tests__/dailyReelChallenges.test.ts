import { describe, expect, it } from "vitest";
import { DailyReelSecurity } from "../dailyReelSecurity.js";
import {
  DAILY_REEL_CHALLENGE_TTL_MS,
  DailyReelChallengeError,
  DailyReelChallengeService,
  InMemoryDailyReelChallengeStore,
  sanitizeDailyReelNickname,
  type DailyReelChallengeSessionGateway,
  type DailyReelCompletedSessionSnapshot,
} from "../dailyReelChallenges.js";

class FakeSessionGateway implements DailyReelChallengeSessionGateway {
  completedSource: DailyReelCompletedSessionSnapshot | null;
  opponentOutcome: { completed: boolean; totalScore?: number; completedAt?: number } = { completed: false };
  starts: Array<Parameters<DailyReelChallengeSessionGateway["startChallengeSession"]>[0]> = [];

  constructor(source: DailyReelCompletedSessionSnapshot | null) {
    this.completedSource = source;
  }

  async getCompletedSession(input: { capability: string; anonymousIdHash: string }) {
    if (input.capability !== "source-capability") return null;
    if (this.completedSource?.anonymousIdHash !== input.anonymousIdHash) return null;
    return this.completedSource;
  }

  async startChallengeSession(input: Parameters<DailyReelChallengeSessionGateway["startChallengeSession"]>[0]) {
    this.starts.push(input);
    return { sessionId: `opponent-${input.challengeId}`, capability: `opponent-cap-${input.challengeId}` };
  }

  async getSessionOutcome() {
    return this.opponentOutcome;
  }
}

function setup(now = 1_800_000_000_000) {
  let clock = now;
  const security = new DailyReelSecurity("daily-reel-unit-test-secret-with-32-bytes");
  const creatorHash = security.hashAnonymousId("creator-install");
  const gateway = new FakeSessionGateway({
    sessionId: "completed-session",
    anonymousIdHash: creatorHash,
    publicationId: "2026-08-28",
    versionId: "version-1",
    locale: "en",
    totalScore: 2470,
    completedAt: now - 1_000,
    experienceConfig: { actCount: 3, assistance: "baseline", resultStyle: "festival" },
    experienceConfigHash: "config-hash-1",
  });
  const store = new InMemoryDailyReelChallengeStore();
  const service = new DailyReelChallengeService(store, gateway, security, "https://play.example.com", () => clock);
  return {
    service,
    gateway,
    store,
    security,
    advance: (milliseconds: number) => { clock += milliseconds; },
  };
}

async function createChallenge(setupResult: ReturnType<typeof setup>, requestId = "request_12345678") {
  return setupResult.service.create({
    sourceSessionCapability: "source-capability",
    anonymousId: "creator-install",
    requestId,
    nickname: "  Movie <Master>  ",
  });
}

describe("DailyReelChallengeService", () => {
  it("requires a completed authoritative source session", async () => {
    const context = setup();
    context.gateway.completedSource = null;
    await expect(createChallenge(context)).rejects.toMatchObject({ code: "challenge.session_incomplete" });
  });

  it("creates an idempotent 48-hour fragment-only capability", async () => {
    const context = setup();
    const first = await createChallenge(context);
    const second = await createChallenge(context);
    expect(second).toEqual(first);
    expect(first.expiresAt).toBe(1_800_000_000_000 + DAILY_REEL_CHALLENGE_TTL_MS);
    const url = new URL(first.shareUrl);
    expect(url.pathname).toBe("/c");
    expect(url.search).toBe("");
    expect(url.hash).toContain(first.capability);
    expect(url.pathname).not.toContain(first.capability);
  });

  it("omits the sender score until the opponent completes", async () => {
    const context = setup();
    const challenge = await createChallenge(context);
    const preview = await context.service.preview(challenge.capability);
    expect(preview.status).toBe("available");
    expect(preview.senderScore).toBeUndefined();
    expect(preview.opponentScore).toBeUndefined();
    expect(preview.senderNickname).toBe("Movie Master");
  });

  it("rejects self-claims", async () => {
    const context = setup();
    const challenge = await createChallenge(context);
    await expect(context.service.claim({ capability: challenge.capability, anonymousId: "creator-install" }))
      .rejects.toMatchObject({ code: "challenge.self_claim" });
  });

  it("atomically gives a challenge to the first non-creator installation", async () => {
    const context = setup();
    const challenge = await createChallenge(context);
    const claims = await Promise.allSettled([
      context.service.claim({ capability: challenge.capability, anonymousId: "friend-a" }),
      context.service.claim({ capability: challenge.capability, anonymousId: "friend-b" }),
    ]);
    expect(claims.filter((result) => result.status === "fulfilled")).toHaveLength(1);
    const rejected = claims.find((result) => result.status === "rejected") as PromiseRejectedResult;
    expect(rejected.reason).toMatchObject({ code: "challenge.already_claimed" });
  });

  it("starts the opponent with the sender's frozen experiment config", async () => {
    const context = setup();
    const challenge = await createChallenge(context);
    await context.service.claim({ capability: challenge.capability, anonymousId: "friend-a" });
    expect(context.gateway.starts).toHaveLength(1);
    expect(context.gateway.starts[0].experienceConfig).toEqual({
      actCount: 3,
      assistance: "baseline",
      resultStyle: "festival",
    });
    expect(context.gateway.starts[0].experienceConfigHash).toBe("config-hash-1");
  });

  it("allows an active claimant to retry but rejects an expired unclaimed challenge", async () => {
    const context = setup();
    const challenge = await createChallenge(context);
    const first = await context.service.claim({ capability: challenge.capability, anonymousId: "friend-a" });
    const retry = await context.service.claim({ capability: challenge.capability, anonymousId: "friend-a" });
    expect(retry.sessionId).toBe(first.sessionId);

    const expiredContext = setup();
    const expired = await createChallenge(expiredContext);
    expiredContext.advance(DAILY_REEL_CHALLENGE_TTL_MS);
    await expect(expiredContext.service.claim({ capability: expired.capability, anonymousId: "friend-b" }))
      .rejects.toMatchObject({ code: "challenge.expired" });
  });

  it("reveals both scores only after authoritative opponent completion", async () => {
    const context = setup();
    const challenge = await createChallenge(context);
    await context.service.claim({ capability: challenge.capability, anonymousId: "friend-a" });
    context.gateway.opponentOutcome = { completed: true, totalScore: 2610, completedAt: 1_800_000_100_000 };
    const result = await context.service.refresh(challenge.capability);
    expect(result).toMatchObject({ status: "completed", senderScore: 2470, opponentScore: 2610 });
  });

  it("sanitizes optional display names without requiring an account", () => {
    expect(sanitizeDailyReelNickname("  Jane\u202e <script> 🎬  ")).toBe("Jane script");
    expect(sanitizeDailyReelNickname("   ")).toBeUndefined();
    expect(Array.from(sanitizeDailyReelNickname("abcdefghijklmnopqrstuvwxyz") ?? "")).toHaveLength(24);
  });

  it("uses typed domain errors", () => {
    expect(new DailyReelChallengeError("example", "message")).toMatchObject({ code: "example" });
  });
});
