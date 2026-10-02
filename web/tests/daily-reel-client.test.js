import assert from "node:assert/strict";
import test from "node:test";
import { consumeChallengeCapability, LiveDailyReelClient } from "../src/daily-reel-client.js";

test("live client keeps capabilities out of URLs and includes App Check", async () => {
  let captured;
  const client = new LiveDailyReelClient({
    baseUrl: "https://example.test/api/",
    appCheckToken: async () => "verified-token",
    identity: { get: async () => "install-1" },
    fetchImpl: async (url, options) => {
      captured = { url, options };
      return new Response(JSON.stringify({ session: { sequence: 2 } }), {
        status: 200,
        headers: { "content-type": "application/json" },
      });
    },
  });

  await client.submitAttempt({
    capability: "secret-capability",
    expectedSequence: 1,
    requestId: "request-12345678",
    answer: ["a", "b"],
  });

  assert.equal(captured.url.pathname, "/api/daily-reel/session/attempt");
  assert.equal(captured.url.search, "");
  assert.equal(captured.url.href.includes("secret-capability"), false);
  assert.equal(captured.options.headers["X-Firebase-AppCheck"], "verified-token");
  assert.deepEqual(JSON.parse(captured.options.body), {
    anonymousId: "install-1",
    capability: "secret-capability",
    expectedSequence: 1,
    requestId: "request-12345678",
    answer: ["a", "b"],
  });
});

test("live client preserves the native fetch receiver", async () => {
  const originalFetch = globalThis.fetch;
  globalThis.fetch = async function () {
    if (this !== globalThis) throw new TypeError("Illegal invocation");
    return new Response(JSON.stringify({ session: { status: "active" } }), {
      status: 200,
      headers: { "content-type": "application/json" },
    });
  };

  try {
    const client = new LiveDailyReelClient({
      baseUrl: "https://example.test/api/",
      appCheckToken: async () => "verified-token",
      identity: { get: async () => "install-native-fetch" },
    });
    const result = await client.start({ publicationId: "2026-08-29", locale: "en-US" });
    assert.equal(result.session.status, "active");
  } finally {
    globalThis.fetch = originalFetch;
  }
});

test("challenge capability is consumed from the fragment and removed from the address bar", () => {
  let replacement;
  const capability = consumeChallengeCapability(
    { hash: "#capability=opaque-friend-cap", pathname: "/c", search: "" },
    { replaceState: (_state, _title, url) => { replacement = url; } },
  );
  assert.equal(capability, "opaque-friend-cap");
  assert.equal(replacement, "/c");
});
