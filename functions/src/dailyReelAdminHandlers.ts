import type { DailyReelRepository, DailyReelReplacementRequest, DailyReelScheduleRecord } from "./dailyReelRepository.js";

export interface DailyReelAdminActor {
  actorId: string;
  canReviewDailyReels: boolean;
}

export class DailyReelAdminAuthorizationError extends Error {}
export class DailyReelAdminInputError extends Error {}

export class DailyReelAdminService {
  constructor(private readonly repository: DailyReelRepository) {}

  async approve(input: {
    candidateId: string;
    publicationId: string;
    actor: DailyReelAdminActor;
  }): Promise<DailyReelScheduleRecord> {
    assertAuthorized(input.actor);
    const candidateId = required(input.candidateId, "candidateId");
    const publicationId = required(input.publicationId, "publicationId");
    return this.repository.approveAndSchedule(candidateId, publicationId, input.actor.actorId);
  }

  async deny(input: {
    candidateId: string;
    actor: DailyReelAdminActor;
  }): Promise<DailyReelReplacementRequest> {
    assertAuthorized(input.actor);
    const candidateId = required(input.candidateId, "candidateId");
    return this.repository.denyAndQueueReplacement(candidateId, input.actor.actorId);
  }
}

function assertAuthorized(actor: DailyReelAdminActor): void {
  if (!actor.canReviewDailyReels || !actor.actorId.trim()) {
    throw new DailyReelAdminAuthorizationError("Daily Reel reviewer authorization is required");
  }
}

function required(value: string, field: string): string {
  const normalized = value.trim();
  if (!normalized) throw new DailyReelAdminInputError(`${field} is required`);
  return normalized;
}
