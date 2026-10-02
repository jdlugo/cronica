import { scoreDailyReelAct } from "./dailyReelScoring.js";

export type DailyReelActStatus = "playing" | "solved" | "revealed" | "exhausted";

export interface DailyReelActProgress {
  status: DailyReelActStatus;
  incorrectAttempts: number;
  scoreAffectingClues: number;
  requestedClueIds: string[];
  score: number | null;
}

export type DailyReelActEvent =
  | { type: "incorrect" }
  | { type: "correct" }
  | { type: "requestClue"; clueId: string; affectsScore: boolean }
  | { type: "reveal" };

export function initialDailyReelActProgress(): DailyReelActProgress {
  return {
    status: "playing",
    incorrectAttempts: 0,
    scoreAffectingClues: 0,
    requestedClueIds: [],
    score: null,
  };
}

export function applyDailyReelActEvent(
  state: DailyReelActProgress,
  event: DailyReelActEvent,
  maxIncorrectAttempts = 3,
): DailyReelActProgress {
  if (state.status !== "playing") {
    return state;
  }

  if (event.type === "requestClue") {
    const clueId = event.clueId.trim();
    if (clueId.length === 0 || state.requestedClueIds.includes(clueId)) {
      return state;
    }
    return {
      ...state,
      requestedClueIds: [...state.requestedClueIds, clueId],
      scoreAffectingClues: state.scoreAffectingClues + (event.affectsScore ? 1 : 0),
    };
  }

  if (event.type === "correct") {
    return {
      ...state,
      status: "solved",
      score: scoreDailyReelAct({
        outcome: "solved",
        incorrectAttempts: state.incorrectAttempts,
        scoreAffectingClues: state.scoreAffectingClues,
      }),
    };
  }

  if (event.type === "reveal") {
    return { ...state, status: "revealed", score: 0 };
  }

  const maximum = Math.max(1, Math.trunc(maxIncorrectAttempts));
  const incorrectAttempts = state.incorrectAttempts + 1;
  if (incorrectAttempts >= maximum) {
    return {
      ...state,
      status: "exhausted",
      incorrectAttempts,
      score: 0,
    };
  }

  return { ...state, incorrectAttempts };
}
