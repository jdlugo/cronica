import assert from "node:assert/strict";
import test from "node:test";
import { appStoreResultCopy, connectionSceneCopy, resultShareText } from "../src/game-copy.js";

test("Connect copy describes a single-film warm-up without inventing three movies", () => {
  assert.deepEqual(connectionSceneCopy({ prompt: "Which year was it released?" }, "Titanic"), {
    transition: "Act 1 complete. Stay with Titanic for one quick detail.",
    question: "Which year was it released?",
  });
});

test("Connect copy preserves the multi-film production framing", () => {
  assert.deepEqual(connectionSceneCopy({ films: [{}, {}, {}] }, "Titanic"), {
    transition: "Act 1 complete. Compare these three different movies.",
    question: "What links these three movies?",
  });
});

test("App Store result copy names the continuing value", () => {
  const copy = appStoreResultCopy();
  assert.match(copy.kicker, /puzzles/i);
  assert.match(copy.kicker, /watchlist/i);
  assert.match(copy.action, /Streaming Now/i);
});

test("rival warm-up shares lead with the winning margin and omit empty Festival progress", () => {
  const copy = resultShareText({
    publicationId: "2026-08-30",
    marks: "🟩🟩🟩",
    score: 2850,
    ticketTitle: "Premiere Cut",
    festivalCount: 0,
    festivalTarget: 5,
    recoveryPreview: true,
    rivalHeadline: "You beat the cut by 100",
  });
  assert.match(copy, /beat the cut by 100/i);
  assert.match(copy, /Warm-up collectible/i);
  assert.doesNotMatch(copy, /Festival 0\/5/);
});
