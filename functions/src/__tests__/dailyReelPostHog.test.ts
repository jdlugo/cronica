import { describe, expect, it } from "vitest";
import { PostHogDailyReelFlagProvider } from "../dailyReelPostHog.js";

describe("PostHogDailyReelFlagProvider", () => {
  it("normalizes v2 boolean and multivariate flag responses", async () => {
    const provider = new PostHogDailyReelFlagProvider(
      "phc_test",
      "https://us.i.posthog.com",
      (async () => new Response(JSON.stringify({
        flags: {
          "daily-reel-rollout": { enabled: true, variant: "internal" },
          "daily-reel-assistance": { enabled: true, variant: "baseline", metadata: { payload: { hintsEnabled: true } } },
          "daily-reel-results": false,
        },
      }))) as typeof fetch,
    );
    await expect(provider.flagsFor("anonymous-hash")).resolves.toMatchObject({
      "daily-reel-rollout": { enabled: true, variant: "internal" },
      "daily-reel-assistance": { enabled: true, variant: "baseline", payload: { hintsEnabled: true } },
      "daily-reel-results": false,
    });
  });

  it("fails closed when PostHog is unavailable", async () => {
    const provider = new PostHogDailyReelFlagProvider(
      "phc_test",
      "https://us.i.posthog.com",
      (async () => new Response("unavailable", { status: 503 })) as typeof fetch,
    );
    await expect(provider.flagsFor("anonymous-hash")).rejects.toThrow("503");
  });
});
