import assert from "node:assert/strict";
import test from "node:test";

import * as machine from "../src/daily-reel-machine.js";

test("completionThreadFor prefers a completion-only thread over the public theme", () => {
  assert.equal(typeof machine.completionThreadFor, "function");

  const result = machine.completionThreadFor({
    role: "arrange",
    title: "The Spielberg time loop",
    explanation: "1984, 1999, 2010. Spielberg links the reel from Back to the Future onward.",
  }, "Extraordinary journeys");

  assert.deepEqual(result, {
    title: "The Spielberg time loop",
    explanation: "1984, 1999, 2010. Spielberg links the reel from Back to the Future onward.",
  });
});

test("completionThreadFor leaves legacy reels on the existing fallback path", () => {
  assert.equal(typeof machine.completionThreadFor, "function");
  assert.equal(machine.completionThreadFor({
    role: "arrange",
    explanation: "The movies opened in 1984, 1999, and 2010.",
  }, "Extraordinary journeys"), null);
});
