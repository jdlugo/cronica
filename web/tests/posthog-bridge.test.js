import assert from "node:assert/strict";
import test from "node:test";
import { isDailyReelRolloutEnabled, PostHogBridge } from "../src/posthog-bridge.js";

test("rollout parser fails closed and accepts named variants", () => {
  assert.equal(isDailyReelRolloutEnabled(undefined), false);
  assert.equal(isDailyReelRolloutEnabled(false), false);
  assert.equal(isDailyReelRolloutEnabled("off"), false);
  assert.equal(isDailyReelRolloutEnabled(true), true);
  assert.equal(isDailyReelRolloutEnabled("internal"), true);
  assert.equal(isDailyReelRolloutEnabled(false, true), true);
});

test("PostHog bridge evaluates and caches the shared rollout flag", async () => {
  let requests = 0;
  const bridge = new PostHogBridge({
    projectToken: "phc_test",
    distinctId: "install-1",
    fetchImpl: async () => {
      requests += 1;
      return new Response(JSON.stringify({ flags: { "daily-reel-rollout": { enabled: true, variant: "beta" } } }));
    },
  });
  assert.equal(await bridge.featureFlag("daily-reel-rollout"), "beta");
  assert.equal(await bridge.featureFlag("daily-reel-rollout"), "beta");
  assert.equal(requests, 1);
});

test("PostHog bridge preserves the native fetch receiver", async () => {
  const originalFetch = globalThis.fetch;
  globalThis.fetch = async function () {
    if (this !== globalThis) throw new TypeError("Illegal invocation");
    return new Response(JSON.stringify({
      flags: { "daily-reel-rollout": { enabled: true, variant: "reel" } },
    }));
  };

  try {
    const bridge = new PostHogBridge({
      projectToken: "phc_test",
      distinctId: "install-native-fetch",
    });
    assert.equal(await bridge.featureFlag("daily-reel-rollout"), "reel");
  } finally {
    globalThis.fetch = originalFetch;
  }
});

test("PostHog bridge sends the ingestion distinct_id property", () => {
  let capturedBody;
  const bridge = new PostHogBridge({
    projectToken: "phc_test",
    distinctId: "install-capture",
    fetchImpl: async (_url, options) => {
      capturedBody = JSON.parse(options.body);
      return new Response(null, { status: 200 });
    },
  });

  bridge.capture("daily_reel_session_started", { publication_id: "2026-08-29" });

  assert.equal(capturedBody.properties.distinct_id, "install-capture");
});
