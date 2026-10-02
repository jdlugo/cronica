export type DailyReelActOutcome = "solved" | "revealed" | "exhausted";

export interface DailyReelActScoreInput {
  outcome: DailyReelActOutcome;
  incorrectAttempts: number;
  scoreAffectingClues: number;
  freeClues?: number;
}

export const DAILY_REEL_MAX_ACT_SCORE = 100;
export const DAILY_REEL_MAX_SCORE = 300;

export function scoreDailyReelAct(input: DailyReelActScoreInput): number {
  if (input.outcome !== "solved") {
    return 0;
  }

  const incorrectAttempts = Math.max(0, Math.trunc(input.incorrectAttempts));
  const scoreAffectingClues = Math.max(0, Math.trunc(input.scoreAffectingClues));
  const assistanceEvents = incorrectAttempts + scoreAffectingClues;

  if (assistanceEvents === 0) {
    return 100;
  }
  if (assistanceEvents === 1) {
    return 75;
  }
  return 50;
}

export function totalDailyReelScore(actScores: readonly number[]): number {
  return Math.min(
    DAILY_REEL_MAX_SCORE,
    actScores.reduce((total, score) => total + Math.max(0, Math.min(100, Math.trunc(score))), 0),
  );
}
