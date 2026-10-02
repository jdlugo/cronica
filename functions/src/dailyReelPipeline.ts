import type {
  DailyReelCandidate,
  DailyReelGenerationRequest,
  DailyReelGenerator,
} from "./dailyReelGenerator.js";
import {
  evaluateDailyReelCandidate,
  type DailyReelQualityContext,
  type DailyReelQualityReport,
} from "./dailyReelQuality.js";
import type { DailyReelRepository } from "./dailyReelRepository.js";

export interface DailyReelPipelineResult {
  candidate: DailyReelCandidate;
  qualityReport: DailyReelQualityReport;
  replacementQueued: boolean;
}

export class DailyReelPipeline {
  constructor(
    private readonly generator: DailyReelGenerator,
    private readonly repository: DailyReelRepository,
    private readonly qualityEvaluator: typeof evaluateDailyReelCandidate = evaluateDailyReelCandidate,
  ) {}

  async generateAndValidate(
    request: DailyReelGenerationRequest,
    qualityContext: DailyReelQualityContext = {},
  ): Promise<DailyReelPipelineResult> {
    const generated = await this.generator.generate(request);
    const persisted = await this.repository.createCandidate(generated);
    const qualityReport = this.qualityEvaluator(persisted, {
      recentMovieIds: request.recentMovieIds,
      recentThemeKeys: request.recentThemeKeys,
      ...qualityContext,
    });
    const candidate = await this.repository.recordValidation(persisted.candidateId, qualityReport);

    if (!qualityReport.passed) {
      await this.repository.queueReplacement(candidate.candidateId, "qualityRejected");
    }
    const finalCandidate = await this.repository.getCandidate(candidate.candidateId);
    if (!finalCandidate) throw new Error("Candidate disappeared after validation");

    return {
      candidate: finalCandidate,
      qualityReport,
      replacementQueued: finalCandidate.replacementQueued,
    };
  }
}
