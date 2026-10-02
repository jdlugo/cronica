import assert from "node:assert/strict";
import test from "node:test";
import { decorateChallengeURL, readRivalContext, rivalResult } from "../src/challenge-context.js";

test("challenge links carry public score context without disturbing the capability", () => {
  const result = decorateChallengeURL("https://example.test/#capability=opaque", {
    score: 2875,
    cut: "Premiere Cut",
  });
  const url = new URL(result);
  assert.equal(url.searchParams.get("rival_score"), "2875");
  assert.equal(url.searchParams.get("rival_cut"), "Premiere Cut");
  assert.equal(url.hash, "#capability=opaque");
});

test("rival context survives recovery and produces a score differential", () => {
  const context = readRivalContext("rival_score=2750&rival_cut=Director%27s+Cut");
  assert.deepEqual(context, { score: 2750, cut: "Director's Cut" });
  assert.deepEqual(rivalResult(3000, context), {
    outcome: "won",
    delta: 250,
    title: "You beat the cut by 250",
  });
});
