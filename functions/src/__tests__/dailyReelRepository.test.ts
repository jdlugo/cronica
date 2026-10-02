import { describe, expect, it } from "vitest";
import { evaluateDailyReelCandidate } from "../dailyReelQuality.js";
import {
  DailyReelRepositoryConflictError,
  InMemoryDailyReelRepository,
} from "../dailyReelRepository.js";
import { makeCandidate } from "./dailyReelTestFixtures.js";

const now = () => new Date("2026-08-28T12:00:00Z");

async function awaitingApproval(repository: InMemoryDailyReelRepository, suffix = "") {
  const base = makeCandidate(suffix ? {
    candidateId: `reel-fixture-${suffix}`,
    generationKey: `fixture-generation-${suffix}`,
    privateReel: {
      ...makeCandidate().privateReel,
      reel: {
        ...makeCandidate().privateReel.reel,
        contentVersion: `fixture-2026-08-28.${suffix}`,
      },
    },
  } : {});
  const created = await repository.createCandidate(base);
  return repository.recordValidation(created.candidateId, evaluateDailyReelCandidate(created, { now }));
}

describe("InMemoryDailyReelRepository", () => {
  it("moves a passing candidate to awaiting approval", async () => {
    const repository = new InMemoryDailyReelRepository(now);

    const candidate = await awaitingApproval(repository);

    expect(candidate.state).toBe("awaitingApproval");
  });

  it("approves and schedules immutably and idempotently", async () => {
    const repository = new InMemoryDailyReelRepository(now);
    const candidate = await awaitingApproval(repository);

    const first = await repository.approveAndSchedule(
      candidate.candidateId,
      candidate.intendedPublicationId,
      "reviewer-hash",
    );
    const second = await repository.approveAndSchedule(
      candidate.candidateId,
      candidate.intendedPublicationId,
      "reviewer-hash",
    );

    expect(second).toEqual(first);
    expect((await repository.getCandidate(candidate.candidateId))?.state).toBe("scheduled");
  });

  it("does not overwrite an occupied publication date", async () => {
    const repository = new InMemoryDailyReelRepository(now);
    const first = await awaitingApproval(repository);
    const second = await awaitingApproval(repository, "second");
    await repository.approveAndSchedule(first.candidateId, first.intendedPublicationId, "reviewer-hash");

    await expect(
      repository.approveAndSchedule(second.candidateId, second.intendedPublicationId, "reviewer-hash"),
    ).rejects.toBeInstanceOf(DailyReelRepositoryConflictError);
  });

  it("denies once and queues exactly one replacement", async () => {
    const repository = new InMemoryDailyReelRepository(now);
    const candidate = await awaitingApproval(repository);

    const first = await repository.denyAndQueueReplacement(candidate.candidateId, "reviewer-hash");
    const second = await repository.denyAndQueueReplacement(candidate.candidateId, "reviewer-hash");

    expect(second).toEqual(first);
    expect((await repository.getCandidate(candidate.candidateId))?.replacementQueued).toBe(true);
  });
});
