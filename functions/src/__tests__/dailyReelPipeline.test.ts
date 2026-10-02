import { describe, expect, it } from "vitest";
import { DailyReelGenerator } from "../dailyReelGenerator.js";
import { DailyReelPipeline } from "../dailyReelPipeline.js";
import { InMemoryDailyReelRepository } from "../dailyReelRepository.js";
import { clone, makeGeneratedPayload } from "./dailyReelTestFixtures.js";

const request = {
  generationKey: "2026-08-28-primary",
  intendedPublicationId: "fixture-2026-08-28",
  themeSeed: "Extraordinary journeys",
  recentMovieIds: [],
  recentThemeKeys: [],
};

describe("DailyReelPipeline", () => {
  it("persists a passing candidate for explicit approval", async () => {
    const repository = new InMemoryDailyReelRepository();
    const generator = new DailyReelGenerator({ generate: async () => makeGeneratedPayload() });
    const pipeline = new DailyReelPipeline(generator, repository);

    const result = await pipeline.generateAndValidate(request);

    expect(result.qualityReport.passed).toBe(true);
    expect(result.candidate.state).toBe("awaitingApproval");
    expect(result.replacementQueued).toBe(false);
  });

  it("rejects bad facts and queues one replacement", async () => {
    const payload = clone(makeGeneratedPayload());
    payload.movieFacts[0].directorIds = ["person:not-spielberg"];
    const repository = new InMemoryDailyReelRepository();
    const generator = new DailyReelGenerator({ generate: async () => payload });
    const pipeline = new DailyReelPipeline(generator, repository);

    const result = await pipeline.generateAndValidate(request);

    expect(result.qualityReport.passed).toBe(false);
    expect(result.candidate.state).toBe("rejected");
    expect(result.replacementQueued).toBe(true);
  });

  it("is idempotent for the same generation key and content version", async () => {
    const repository = new InMemoryDailyReelRepository();
    const generator = new DailyReelGenerator({ generate: async () => makeGeneratedPayload() });
    const pipeline = new DailyReelPipeline(generator, repository);

    const first = await pipeline.generateAndValidate(request);
    const second = await pipeline.generateAndValidate(request);

    expect(second.candidate.candidateId).toBe(first.candidate.candidateId);
    expect(second.candidate.state).toBe("awaitingApproval");
  });
});
