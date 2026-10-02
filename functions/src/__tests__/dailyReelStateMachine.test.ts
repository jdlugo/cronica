import { readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";
import {
  applyDailyReelActEvent,
  type DailyReelActEvent,
  type DailyReelActProgress,
} from "../dailyReelStateMachine.js";

interface TransitionFixture {
  maxIncorrectAttemptsPerAct: number;
  scenarios: Array<{
    name: string;
    initial: DailyReelActProgress;
    events: DailyReelActEvent[];
    expected: DailyReelActProgress;
  }>;
}

const fixtureUrl = new URL(
  "../../../contracts/daily-reel/v1/fixtures/session-transitions.json",
  import.meta.url,
);

const fixture = JSON.parse(readFileSync(fixtureUrl, "utf8")) as TransitionFixture;

describe("applyDailyReelActEvent", () => {
  for (const scenario of fixture.scenarios) {
    it(scenario.name, () => {
      const result = scenario.events.reduce(
        (state, event) =>
          applyDailyReelActEvent(state, event, fixture.maxIncorrectAttemptsPerAct),
        scenario.initial,
      );

      expect(result).toEqual(scenario.expected);
    });
  }

  it("ignores events after an act reaches a terminal state", () => {
    const solved: DailyReelActProgress = {
      status: "solved",
      incorrectAttempts: 0,
      scoreAffectingClues: 0,
      requestedClueIds: [],
      score: 100,
    };

    expect(applyDailyReelActEvent(solved, { type: "incorrect" })).toBe(solved);
  });
});
