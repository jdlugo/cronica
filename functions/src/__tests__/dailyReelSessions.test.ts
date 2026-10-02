import { describe, expect, it } from "vitest";
import { DailyReelExperienceResolver } from "../dailyReelExperience.js";
import { DailyReelSecurity } from "../dailyReelSecurity.js";
import {
  DailyReelSessionError,
  DailyReelSessionService,
  InMemoryDailyReelContentStore,
  InMemoryDailyReelSessionStore,
  type DailyReelSessionRecord,
  type DailyReelSessionStore,
} from "../dailyReelSessions.js";
import { makePrivateReel } from "./dailyReelTestFixtures.js";

class FirestoreStrictSessionStore implements DailyReelSessionStore {
  private readonly delegate = new InMemoryDailyReelSessionStore();

  async get(capabilityHash: string) {
    return this.delegate.get(capabilityHash);
  }

  async createIfAbsent(record: DailyReelSessionRecord) {
    assertNoUndefined(record);
    return this.delegate.createIfAbsent(record);
  }

  async mutate<T>(
    capabilityHash: string,
    mutation: (record: DailyReelSessionRecord) => { record: DailyReelSessionRecord; result: T },
  ): Promise<T> {
    return this.delegate.mutate(capabilityHash, (record) => {
      const outcome = mutation(record);
      assertNoUndefined(outcome.record);
      return outcome;
    });
  }
}

function assertNoUndefined(value: unknown, path = "record"): void {
  if (value === undefined) throw new Error(`Firestore-incompatible undefined at ${path}`);
  if (Array.isArray(value)) {
    value.forEach((item, index) => assertNoUndefined(item, `${path}[${index}]`));
    return;
  }
  if (value && typeof value === "object") {
    Object.entries(value as Record<string, unknown>).forEach(([key, item]) => {
      assertNoUndefined(item, `${path}.${key}`);
    });
  }
}

function setup(
  rollout = true,
  now = "2026-08-28T12:00:00Z",
  options: { omitThreadReveal?: boolean; sessions?: DailyReelSessionStore } = {},
) {
  const content = new InMemoryDailyReelContentStore();
  const privateReel = makePrivateReel();
  if (options.omitThreadReveal) {
    Object.values(privateReel.answers).forEach((answers) => delete answers.threadReveal);
  }
  content.put({
    publicationId: privateReel.reel.publicationId,
    versionId: privateReel.reel.contentVersion,
    privateReel,
  });
  const sessions = options.sessions ?? new InMemoryDailyReelSessionStore();
  const experience = new DailyReelExperienceResolver({
    flagsFor: async () => ({ "daily-reel-rollout": rollout }),
  });
  const service = new DailyReelSessionService(
    sessions,
    content,
    experience,
    new DailyReelSecurity("unit-test-secret-that-is-at-least-32-bytes"),
    () => new Date(now),
  );
  return { service, privateReel };
}

async function start(service: DailyReelSessionService) {
  return service.start({
    anonymousId: "install-123",
    publicationId: "fixture-2026-08-28",
    locale: "en",
  });
}

describe("DailyReelSessionService", () => {
  it("does not create a session for a rollout-disabled installation", async () => {
    const { service } = setup(false);

    await expect(start(service)).rejects.toMatchObject({ code: "experience.ineligible" });
  });

  it("rejects early and expired daily sessions but preserves frozen challenge access", async () => {
    const early = setup(true, "2026-08-28T04:59:59Z").service;
    const expired = setup(true, "2026-08-29T05:00:00Z").service;

    await expect(start(early)).rejects.toMatchObject({ code: "content.unavailable" });
    await expect(start(expired)).rejects.toMatchObject({ code: "content.unavailable" });

    const challenge = await expired.start({
      anonymousId: "install-123",
      publicationId: "fixture-2026-08-28",
      locale: "en",
      mode: "challenge",
    });
    expect(challenge.session.mode).toBe("challenge");
  });

  it("starts and resumes the same opaque server-authoritative session", async () => {
    const { service } = setup();

    const first = await start(service);
    const second = await start(service);
    const resumed = await service.resume(first.capability);

    expect(first.capability).toBe(second.capability);
    expect(first.session.sessionId).toBe(second.session.sessionId);
    expect(resumed.currentAct?.role).toBe("decode");
    expect(resumed.currentActIndex).toBe(0);
    expect(JSON.stringify(resumed)).not.toContain("acceptedAnswers");
    expect(JSON.stringify(resumed)).not.toContain("correctChoiceId");
    expect(JSON.stringify(resumed)).not.toContain("correctOrder");
  });

  it("scores one wrong Decode attempt then a correct answer at seventy-five", async () => {
    const { service } = setup();
    const session = await start(service);

    const wrong = await service.submitAttempt({
      capability: session.capability,
      requestId: "attempt-1",
      expectedSequence: 0,
      answer: "The Matrix",
    });
    const correct = await service.submitAttempt({
      capability: session.capability,
      requestId: "attempt-2",
      expectedSequence: 1,
      answer: "Back to the Future",
    });

    expect(wrong.correct).toBe(false);
    expect(correct.correct).toBe(true);
    expect(correct.session.acts[0].score).toBe(75);
    expect(correct.session.currentAct?.role).toBe("connect");
  });

  it("keeps the free title-length clue score-neutral and idempotent", async () => {
    const { service } = setup();
    const session = await start(service);

    const clue = await service.requestAssist({
      capability: session.capability,
      requestId: "clue-1",
      expectedSequence: 0,
      assistId: "title-length",
    });
    const retry = await service.requestAssist({
      capability: session.capability,
      requestId: "clue-1",
      expectedSequence: 0,
      assistId: "title-length",
    });
    const correct = await service.submitAttempt({
      capability: session.capability,
      requestId: "attempt-1",
      expectedSequence: 1,
      answer: "Back to the Future",
    });

    expect(clue.assist?.titleLength).toBe(15);
    expect(retry).toEqual(clue);
    expect(correct.session.acts[0].score).toBe(100);
  });

  it("counts a standard hint as one assistance event", async () => {
    const { service } = setup();
    const session = await start(service);
    await service.requestAssist({
      capability: session.capability,
      requestId: "hint-1",
      expectedSequence: 0,
      assistId: "standard-hint",
    });

    const correct = await service.submitAttempt({
      capability: session.capability,
      requestId: "attempt-1",
      expectedSequence: 1,
      answer: "Back to the Future",
    });

    expect(correct.session.acts[0].score).toBe(75);
  });

  it("exhausts on the third incorrect answer and reveals only that act", async () => {
    const { service } = setup();
    const session = await start(service);
    await service.submitAttempt({ capability: session.capability, requestId: "a1", expectedSequence: 0, answer: "x" });
    await service.submitAttempt({ capability: session.capability, requestId: "a2", expectedSequence: 1, answer: "y" });
    const exhausted = await service.submitAttempt({
      capability: session.capability,
      requestId: "a3",
      expectedSequence: 2,
      answer: "z",
    });

    expect(exhausted.actTerminal).toBe(true);
    expect(exhausted.reveal?.title).toBe("Back to the Future");
    expect(exhausted.session.acts[0].score).toBe(0);
    expect(exhausted.session.currentAct?.role).toBe("connect");
    expect(JSON.stringify(exhausted)).not.toContain("tmdb:218,tmdb:603,tmdb:27205");
  });

  it("returns authoritative state without mutation for a stale sequence", async () => {
    const { service } = setup();
    const session = await start(service);
    await service.submitAttempt({
      capability: session.capability,
      requestId: "a1",
      expectedSequence: 0,
      answer: "wrong",
    });

    const stale = await service.submitAttempt({
      capability: session.capability,
      requestId: "a2",
      expectedSequence: 0,
      answer: "wrong again",
    });

    expect(stale.disposition).toBe("stale");
    expect(stale.session.sequence).toBe(1);
    expect(stale.session.acts[0].incorrectAttempts).toBe(1);
  });

  it("completes all three acts for a server-owned total of three hundred", async () => {
    const { service } = setup();
    const session = await start(service);
    const decode = await service.submitAttempt({
      capability: session.capability,
      requestId: "decode",
      expectedSequence: 0,
      answer: "Back to the Future",
    });
    const connect = await service.submitAttempt({
      capability: session.capability,
      requestId: "connect",
      expectedSequence: decode.session.sequence,
      answer: "c1",
    });
    const arrange = await service.submitAttempt({
      capability: session.capability,
      requestId: "arrange",
      expectedSequence: connect.session.sequence,
      answer: ["tmdb:218", "tmdb:603", "tmdb:27205"],
    });

    expect(arrange.session.status).toBe("completed");
    expect(arrange.session.currentAct).toBeNull();
    expect(arrange.session.totalScore).toBe(300);
  });

  it("completes a legacy reel without persisting undefined hidden-thread fields", async () => {
    const { service } = setup(true, "2026-08-28T12:00:00Z", {
      omitThreadReveal: true,
      sessions: new FirestoreStrictSessionStore(),
    });
    const session = await start(service);
    const decode = await service.submitAttempt({
      capability: session.capability,
      requestId: "legacy-decode",
      expectedSequence: 0,
      answer: "Back to the Future",
    });
    const connect = await service.submitAttempt({
      capability: session.capability,
      requestId: "legacy-connect",
      expectedSequence: decode.session.sequence,
      answer: "c1",
    });
    const arrange = await service.submitAttempt({
      capability: session.capability,
      requestId: "legacy-arrange",
      expectedSequence: connect.session.sequence,
      answer: ["tmdb:218", "tmdb:603", "tmdb:27205"],
    });

    expect(arrange.session.status).toBe("completed");
    expect(arrange.reveal).toMatchObject({
      role: "arrange",
      explanation: "The films were released in 1984, 1999, and 2010.",
    });
    expect(arrange.reveal).not.toHaveProperty("title");
    expect(arrange.reveal).not.toHaveProperty("threadTitle");
  });

  it("keeps the hidden thread private until the final act reveal", async () => {
    const { service } = setup();
    const session = await start(service);
    const decode = await service.submitAttempt({
      capability: session.capability,
      requestId: "decode-thread",
      expectedSequence: 0,
      answer: "Back to the Future",
    });
    const connect = await service.submitAttempt({
      capability: session.capability,
      requestId: "connect-thread",
      expectedSequence: decode.session.sequence,
      answer: "c1",
    });
    const arrange = await service.submitAttempt({
      capability: session.capability,
      requestId: "arrange-thread",
      expectedSequence: connect.session.sequence,
      answer: ["tmdb:218", "tmdb:603", "tmdb:27205"],
    });

    expect(JSON.stringify(session.session)).not.toContain("Spielberg time loop");
    expect(JSON.stringify(decode.reveal)).not.toContain("Spielberg time loop");
    expect(JSON.stringify(connect.reveal)).not.toContain("Spielberg time loop");
    expect(arrange.reveal).toMatchObject({
      threadTitle: "The Spielberg time loop",
      threadExplanation: expect.stringContaining("executive-produced Back to the Future"),
    });
  });

  it("rejects unknown capabilities", async () => {
    const { service } = setup();

    await expect(service.resume("unknown-capability")).rejects.toBeInstanceOf(DailyReelSessionError);
  });
});
