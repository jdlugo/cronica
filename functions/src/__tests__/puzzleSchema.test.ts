import { describe, expect, it } from "vitest";

import { normalizeAiPuzzlePayload, validateDailyPuzzleDocument } from "../puzzleSchema.js";

describe("puzzle schema", () => {
  it("normalizes ai output into required puzzle schema", () => {
    const normalized = normalizeAiPuzzlePayload({
      emoji_clue: "🚢 🧊 ❤️",
      hint_1: "Released in 1997",
      hint_2: "Directed by James Cameron",
      accepted_answers: ["Titanic", "  titanic  ", "TITANIC"]
    });

    expect(normalized.emoji_clue).toBe("🚢🧊❤️");
    expect(normalized.hint_1).toBe("Released in 1997");
    expect(normalized.hint_2).toBe("Directed by James Cameron");
    expect(normalized.accepted_answers).toEqual(["titanic"]);
  });

  it("rejects invalid ai payload", () => {
    expect(() =>
      normalizeAiPuzzlePayload({
        emoji_clue: "",
        hint_1: "too short",
        hint_2: "still too short",
        accepted_answers: []
      })
    ).toThrow();
  });

  it("validates the final daily puzzle document", () => {
    const validated = validateDailyPuzzleDocument({
      date: "2026-02-15",
      puzzle_id: "2026-02-15",
      media_type: "movie",
      tmdb_id: 597,
      title: "Titanic",
      emoji_clue: "🚢🧊❤️",
      hint_1: "Released in 1997",
      hint_2: "Directed by James Cameron",
      accepted_answers: ["titanic"],
      source: "ai+tmdb",
      practice_eligible: true,
      generated_at: "2026-02-15T05:00:00.000Z"
    });

    expect(validated.puzzle_id).toBe("2026-02-15");
    expect(validated.accepted_answers).toEqual(["titanic"]);
  });

  it("validates additive locale content while preserving canonical fields", () => {
    const validated = validateDailyPuzzleDocument({
      date: "2026-02-15",
      puzzle_id: "2026-02-15",
      media_type: "movie",
      tmdb_id: 597,
      title: "Titanic",
      emoji_clue: "🚢🧊❤️",
      hint_1: "Released in 1997",
      hint_2: "Directed by James Cameron",
      accepted_answers: ["titanic"],
      localizations: {
        "pt-BR": {
          title: "Titanic",
          emoji_clue: "🚢🧊❤️",
          hint_1: "Lançado nos cinemas em 1997",
          hint_2: "Dirigido por James Cameron",
          accepted_answers: ["titanic"]
        }
      },
      source: "ai+tmdb",
      practice_eligible: true,
      generated_at: "2026-02-15T05:00:00.000Z"
    });

    expect(validated.puzzle_id).toBe("2026-02-15");
    expect(validated.localizations?.["pt-BR"]?.hint_1).toContain("1997");
  });
});
