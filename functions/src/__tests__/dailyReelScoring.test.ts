import { readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";
import {
  scoreDailyReelAct,
  totalDailyReelScore,
  type DailyReelActScoreInput,
} from "../dailyReelScoring.js";

interface ScoringFixture {
  cases: Array<{
    name: string;
    input: DailyReelActScoreInput;
    expectedScore: number;
  }>;
}

const fixtureUrl = new URL(
  "../../../contracts/daily-reel/v1/fixtures/scoring-cases.json",
  import.meta.url,
);

const fixture = JSON.parse(readFileSync(fixtureUrl, "utf8")) as ScoringFixture;

describe("scoreDailyReelAct", () => {
  for (const testCase of fixture.cases) {
    it(testCase.name, () => {
      expect(scoreDailyReelAct(testCase.input)).toBe(testCase.expectedScore);
    });
  }

  it("does not let free clues reduce a solved score", () => {
    expect(
      scoreDailyReelAct({
        outcome: "solved",
        incorrectAttempts: 0,
        scoreAffectingClues: 0,
        freeClues: 50,
      }),
    ).toBe(100);
  });
});

describe("totalDailyReelScore", () => {
  it("adds three act scores and caps the total at 300", () => {
    expect(totalDailyReelScore([100, 75, 50])).toBe(225);
    expect(totalDailyReelScore([200, 200, 200])).toBe(300);
  });
});
