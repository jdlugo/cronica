import test from "node:test";
import assert from "node:assert/strict";
import { contentAttribution } from "../src/session-telemetry.js";

test("attributes telemetry to both the publication and immutable content version", () => {
  assert.deepEqual(
    contentAttribution(
      { publicationId: "2026-08-31", contentVersion: "daily-reel-2026-08-31.1" },
      "fallback",
    ),
    {
      publication_id: "2026-08-31",
      content_version: "daily-reel-2026-08-31.1",
    },
  );
});

test("keeps pre-session events queryable without inventing a content version", () => {
  assert.deepEqual(contentAttribution(null, "2026-08-31"), {
    publication_id: "2026-08-31",
    content_version: "unknown",
  });
});

test("attributes legacy preview sessions by versionId", () => {
  assert.deepEqual(
    contentAttribution({ publicationId: "2026-08-31", versionId: "preview-v1" }, "fallback"),
    {
      publication_id: "2026-08-31",
      content_version: "preview-v1",
    },
  );
});
