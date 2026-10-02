import { describe, expect, it } from "vitest";
import {
  DailyReelAdminAuthorizationError,
  DailyReelAdminService,
} from "../dailyReelAdminHandlers.js";
import { evaluateDailyReelCandidate } from "../dailyReelQuality.js";
import { InMemoryDailyReelRepository } from "../dailyReelRepository.js";
import { makeCandidate } from "./dailyReelTestFixtures.js";

async function setup() {
  const repository = new InMemoryDailyReelRepository();
  const created = await repository.createCandidate(makeCandidate());
  await repository.recordValidation(created.candidateId, evaluateDailyReelCandidate(created));
  return { repository, service: new DailyReelAdminService(repository), candidate: created };
}

describe("DailyReelAdminService", () => {
  it("requires explicit reviewer authorization", async () => {
    const { service, candidate } = await setup();

    await expect(service.approve({
      candidateId: candidate.candidateId,
      publicationId: candidate.intendedPublicationId,
      actor: { actorId: "viewer", canReviewDailyReels: false },
    })).rejects.toBeInstanceOf(DailyReelAdminAuthorizationError);
  });

  it("approves an approval-ready candidate", async () => {
    const { service, candidate } = await setup();

    const schedule = await service.approve({
      candidateId: candidate.candidateId,
      publicationId: candidate.intendedPublicationId,
      actor: { actorId: "reviewer-hash", canReviewDailyReels: true },
    });

    expect(schedule.candidateId).toBe(candidate.candidateId);
  });

  it("denies without collecting a reason and queues replacement", async () => {
    const { service, candidate } = await setup();

    const replacement = await service.deny({
      candidateId: candidate.candidateId,
      actor: { actorId: "reviewer-hash", canReviewDailyReels: true },
    });

    expect(replacement.reasonCode).toBe("editorDenied");
  });
});
