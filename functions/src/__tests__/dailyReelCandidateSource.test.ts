import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";
import { loadDailyReelCandidateSource } from "../dailyReelCandidateSource.js";
import { DailyReelGenerator } from "../dailyReelGenerator.js";
import { DailyReelPipeline } from "../dailyReelPipeline.js";
import { InMemoryDailyReelRepository } from "../dailyReelRepository.js";

const candidatePath = fileURLToPath(new URL(
  "../../../contracts/daily-reel/v1/candidates/2026-09-03.json",
  import.meta.url,
));

describe("Daily Reel production candidate source", () => {
  it("builds a poster-backed localized candidate that passes every quality gate", async () => {
    const source = await loadDailyReelCandidateSource(candidatePath);
    const result = await new DailyReelPipeline(
      new DailyReelGenerator({ generate: async () => source.payload }),
      new InMemoryDailyReelRepository(),
    ).generateAndValidate(source.request);
    const filmCards = Object.values(source.payload.privateReel.reel.localized)
      .flatMap((content) => content.acts)
      .flatMap((act) => "films" in act ? act.films : []);

    expect(result.qualityReport.passed).toBe(true);
    expect(result.candidate.state).toBe("awaitingApproval");
    expect(filmCards).not.toHaveLength(0);
    expect(filmCards.every((film) => film.posterPath?.startsWith("/"))).toBe(true);
  });
});
