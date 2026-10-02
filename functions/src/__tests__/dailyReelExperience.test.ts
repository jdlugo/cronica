import { describe, expect, it } from "vitest";
import {
  DailyReelExperienceResolver,
  InMemoryDailyReelExperienceCache,
  baselineDailyReelExperienceConfig,
  type DailyReelFlagProvider,
} from "../dailyReelExperience.js";

describe("DailyReelExperienceResolver", () => {
  it("keeps a rollout-disabled installation ineligible", async () => {
    const resolver = new DailyReelExperienceResolver({
      flagsFor: async () => ({ "daily-reel-rollout": false }),
    });

    expect((await resolver.resolve("anon")).eligible).toBe(false);
  });

  it("normalizes only allowlisted payload values into a stable configuration", async () => {
    const provider: DailyReelFlagProvider = {
      flagsFor: async () => ({
        "daily-reel-rollout": { enabled: true, variant: "reel" },
        "daily-reel-assistance": {
          enabled: true,
          variant: "no-title-length",
          payload: { titleLengthEnabled: false, arbitraryRule: "ignored" },
        },
        "daily-reel-results": {
          enabled: true,
          variant: "pick-tonight",
          payload: { pickTonightEnabled: true, inActAd: true },
        },
      }),
    };
    const resolver = new DailyReelExperienceResolver(provider);

    const first = await resolver.resolve("anon");
    const second = await resolver.resolve("anon");

    expect(first.eligible).toBe(true);
    expect(first.config?.assistance.titleLength.enabled).toBe(false);
    expect(first.config).not.toHaveProperty("inActAd");
    expect(second.configId).toBe(first.configId);
  });

  it("uses a validated cached assignment when PostHog is temporarily unavailable", async () => {
    let shouldFail = false;
    const cache = new InMemoryDailyReelExperienceCache();
    const resolver = new DailyReelExperienceResolver({
      flagsFor: async () => {
        if (shouldFail) throw new Error("offline");
        return { "daily-reel-rollout": true };
      },
    }, cache);

    const first = await resolver.resolve("anon");
    shouldFail = true;
    const second = await resolver.resolve("anon");

    expect(first.assignmentSource).toBe("posthog");
    expect(second.assignmentSource).toBe("cache");
    expect(second.configId).toBe(first.configId);
  });

  it("fails closed when PostHog and cache are both unavailable", async () => {
    const resolver = new DailyReelExperienceResolver({
      flagsFor: async () => { throw new Error("offline"); },
    });

    expect((await resolver.resolve("new-anon")).eligible).toBe(false);
  });

  it("accepts only a schema-valid frozen challenge configuration", () => {
    const resolver = new DailyReelExperienceResolver({ flagsFor: async () => ({}) });
    const frozen = resolver.resolveFrozen(baselineDailyReelExperienceConfig());

    expect(frozen.assignmentSource).toBe("challenge");
    expect(frozen.eligible).toBe(true);
  });
});
