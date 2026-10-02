import type { DailyReelChallengeService } from "./dailyReelChallenges.js";
import type { DailyReelRequestGuard } from "./dailyReelRequestGuards.js";

export interface DailyReelGuardedRequest {
  appCheckToken: string;
  anonymousId: string;
}

export class DailyReelChallengeHandlers {
  constructor(
    private readonly challenges: DailyReelChallengeService,
    private readonly guard: DailyReelRequestGuard,
  ) {}

  async create(request: DailyReelGuardedRequest & {
    sourceSessionCapability: string;
    requestId: string;
    nickname?: string;
  }) {
    await this.guard.authorize({ route: "challenge.create", ...request });
    return this.challenges.create(request);
  }

  async preview(request: DailyReelGuardedRequest & { capability: string }) {
    await this.guard.authorize({ route: "challenge.read", ...request });
    return this.challenges.preview(request.capability);
  }

  async claim(request: DailyReelGuardedRequest & { capability: string }) {
    await this.guard.authorize({ route: "challenge.claim", ...request });
    return this.challenges.claim(request);
  }

  async refresh(request: DailyReelGuardedRequest & { capability: string }) {
    await this.guard.authorize({ route: "challenge.read", ...request });
    return this.challenges.refresh(request.capability);
  }
}
