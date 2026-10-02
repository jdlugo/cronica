import assert from "node:assert/strict";
import test from "node:test";
import { deliverShare } from "../src/share-delivery.js";

test("native sharing reports a completed text share", async () => {
  const result = await deliverShare({
    navigatorRef: { share: async () => {} },
    shareData: { title: "Daily Reel", text: "score" },
    fallbackText: "score",
    presentFallback: () => assert.fail("fallback should not be shown"),
  });
  assert.deepEqual(result, { outcome: "shared", format: "text" });
});

test("unsupported sharing always presents a visible copy fallback", async () => {
  let presented;
  const result = await deliverShare({
    navigatorRef: {},
    shareData: { title: "Daily Reel", text: "score" },
    fallbackText: "score and link",
    presentFallback: (value) => { presented = value; },
  });
  assert.equal(presented, "score and link");
  assert.deepEqual(result, { outcome: "fallback", format: "copy_panel" });
});

test("native share failures fall back while user cancellation stays quiet", async () => {
  let fallbacks = 0;
  const failed = await deliverShare({
    navigatorRef: { share: async () => { throw new Error("unavailable"); } },
    shareData: { text: "score" },
    fallbackText: "score",
    presentFallback: () => { fallbacks += 1; },
  });
  const cancelled = await deliverShare({
    navigatorRef: { share: async () => { throw Object.assign(new Error("cancelled"), { name: "AbortError" }); } },
    shareData: { text: "score" },
    fallbackText: "score",
    presentFallback: () => { fallbacks += 1; },
  });
  assert.deepEqual(failed, { outcome: "fallback", format: "copy_panel" });
  assert.deepEqual(cancelled, { outcome: "cancelled", format: "native" });
  assert.equal(fallbacks, 1);
});
