import test from "node:test";
import assert from "node:assert/strict";
import { dailyReelPublicationId } from "../src/daily-reel-calendar.js";

test("Daily Reel publication changes at 05:00 UTC", () => {
  assert.equal(dailyReelPublicationId(new Date("2026-09-03T04:59:59Z")), "2026-09-02");
  assert.equal(dailyReelPublicationId(new Date("2026-09-03T05:00:00Z")), "2026-09-03");
});
