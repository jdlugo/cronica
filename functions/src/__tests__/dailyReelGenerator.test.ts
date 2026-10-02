import { describe, expect, it } from "vitest";
import { DailyReelGenerator, type DailyReelDraftProvider } from "../dailyReelGenerator.js";
import { clone, makeGeneratedPayload } from "./dailyReelTestFixtures.js";

const request = {
  generationKey: "2026-08-28-primary",
  intendedPublicationId: "fixture-2026-08-28",
  themeSeed: "Extraordinary journeys",
  recentMovieIds: [],
  recentThemeKeys: [],
};

describe("DailyReelGenerator", () => {
  it("validates provider output and creates a deterministic generated candidate", async () => {
    const provider: DailyReelDraftProvider = {
      generate: async () => makeGeneratedPayload(),
    };
    const generator = new DailyReelGenerator(provider, () => new Date("2026-08-28T12:00:00Z"));

    const first = await generator.generate(request);
    const second = await generator.generate(request);

    expect(first.state).toBe("generated");
    expect(first.candidateId).toBe(second.candidateId);
    expect(first.privateReel.reel.supportedLocales).toHaveLength(5);
    expect(first.createdAt).toBe("2026-08-28T12:00:00.000Z");
  });

  it("rejects provider output with an incomplete locale set", async () => {
    const payload = clone(makeGeneratedPayload()) as unknown as {
      privateReel: { reel: { localized: Record<string, unknown> } };
    };
    delete payload.privateReel.reel.localized["es-ES"];
    const generator = new DailyReelGenerator({ generate: async () => payload });

    await expect(generator.generate(request)).rejects.toThrow();
  });

  it("rejects a generated publication that does not match the request", async () => {
    const payload = clone(makeGeneratedPayload());
    payload.privateReel.reel.publicationId = "another-publication";
    const generator = new DailyReelGenerator({ generate: async () => payload });

    await expect(generator.generate(request)).rejects.toThrow(/publication ID/i);
  });
});
