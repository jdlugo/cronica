import assert from "node:assert/strict";
import test from "node:test";

import { createDailyReelProgressStore, nextReelCountdown } from "../src/daily-reel-progress.js";

class MemoryStorage {
  constructor() { this.values = new Map(); }
  getItem(key) { return this.values.get(key) ?? null; }
  setItem(key, value) { this.values.set(key, value); }
}

function session(publicationId, mode = "daily") {
  return { publicationId, mode, totalScore: 2_750 };
}

test("daily completions build a forgiving five-reel Festival and streak", () => {
  const storage = new MemoryStorage();
  const store = createDailyReelProgressStore({
    storage,
    now: () => new Date("2026-08-29T12:00:00Z"),
  });

  for (const id of ["2026-08-25", "2026-08-26", "2026-08-27", "2026-08-28"]) {
    const result = store.recordCompletion(session(id));
    assert.equal(result.badgeAwarded, false);
  }
  const result = store.recordCompletion(session("2026-08-29"));

  assert.equal(result.changed, true);
  assert.equal(result.festivalCount, 5);
  assert.equal(result.festivalComplete, true);
  assert.equal(result.streak, 5);
  assert.equal(result.badgeAwarded, true);
  assert.equal(store.recordCompletion(session("2026-08-29")).changed, false);
});

test("practice completions never change Daily Festival progress", () => {
  const store = createDailyReelProgressStore({ storage: new MemoryStorage() });
  const result = store.recordCompletion(session("2026-08-29", "practice"));

  assert.equal(result.changed, false);
  assert.equal(result.festivalCount, 0);
  assert.equal(result.totalCompleted, 0);
});

test("next Reel countdown follows the 05:00 UTC publication boundary", () => {
  assert.equal(nextReelCountdown(new Date("2026-08-29T04:30:00Z")), "0h 30m");
  assert.equal(nextReelCountdown(new Date("2026-08-29T05:00:00Z")), "24h 00m");
});
