import assert from "node:assert/strict";
import test from "node:test";
import { DemoDailyReelClient } from "../src/demo-client.js";

test("preview returns the same solved-act reveal shape as production", async () => {
  const client = new DemoDailyReelClient();
  await client.start({ publicationId: "preview", locale: "en", mode: "daily" });
  const response = await client.submitAttempt({ answer: "Titanic" });
  assert.equal(response.correct, true);
  assert.equal(response.reveal.title, "Titanic");
  assert.match(response.reveal.explanation, /ship, iceberg, and love story/i);
  assert.equal(response.session.currentAct.role, "connect");
});

test("preview title-length clue is concrete", async () => {
  const client = new DemoDailyReelClient();
  await client.start({ publicationId: "preview", locale: "en", mode: "daily" });
  const response = await client.requestAssist({ kind: "titleLength" });
  assert.equal(response.assist.titleLength, 7);
  assert.equal(response.session.currentProgress.usedFreeClue, true);
});
