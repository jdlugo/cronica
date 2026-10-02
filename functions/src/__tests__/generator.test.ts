import { describe, expect, it } from "vitest";

import {
  generateDailyPuzzleDocument,
  formatPushBodyFromEmojiClue,
  type OpenAiPuzzleGenerator
} from "../generator.js";

describe("daily puzzle generator", () => {
  it("builds a valid puzzle document from tmdb + ai outputs", async () => {
    const tmdbFetcher = async () => ({
      id: 597,
      title: "Titanic",
      overview: "A seventeen-year-old aristocrat falls in love.",
      popularity: 68,
      vote_count: 25000,
      vote_average: 7.9,
      release_date: "1997-11-18",
      adult: false
    });

    const aiGenerator: OpenAiPuzzleGenerator = {
      async generatePuzzleFields() {
        return {
          emoji_clue: "🚢 🧊 ❤️",
          hint_1: "Released in 1997",
          hint_2: "Directed by James Cameron",
          accepted_answers: ["Titanic"]
        };
      }
    };

    const puzzle = await generateDailyPuzzleDocument({
      targetDate: new Date("2026-02-15T05:00:00Z"),
      tmdbFetcher,
      aiGenerator
    });

    expect(puzzle.puzzle_id).toBe("2026-02-15");
    expect(puzzle.tmdb_id).toBe(597);
    expect(puzzle.emoji_clue).toBe("🚢🧊❤️");
    expect(puzzle.accepted_answers).toEqual(["titanic"]);
    expect(puzzle.practice_eligible).toBe(true);
    expect(puzzle.generated_at).toMatch(/^2026-02-15T05:00:00.000Z$/);
  });

  it("merges canonical title into accepted answers when ai omits it", async () => {
    const tmdbFetcher = async () => ({
      id: 597,
      title: "Titanic",
      overview: "A seventeen-year-old aristocrat falls in love.",
      popularity: 68,
      vote_count: 25000,
      vote_average: 7.9,
      release_date: "1997-11-18",
      adult: false
    });

    const aiGenerator: OpenAiPuzzleGenerator = {
      async generatePuzzleFields() {
        return {
          emoji_clue: "🚢 🧊 ❤️",
          hint_1: "Released in 1997",
          hint_2: "Won multiple Oscars",
          accepted_answers: ["The Ship of Dreams"]
        };
      }
    };

    const puzzle = await generateDailyPuzzleDocument({
      targetDate: new Date("2026-02-15T05:00:00Z"),
      tmdbFetcher,
      aiGenerator
    });

    expect(puzzle.accepted_answers).toEqual(["the ship of dreams", "titanic"]);
  });

  it("formats push body in locked teaser format", () => {
    expect(formatPushBodyFromEmojiClue("🚢🧊❤️")).toBe("🚢 + 🧊 + ❤️ = ______");
  });

  it("retries ai generation when first attempt fails quality and succeeds on a later attempt", async () => {
    const tmdbFetcher = async () => ({
      id: 597,
      title: "Titanic",
      overview: "A seventeen-year-old aristocrat falls in love.",
      popularity: 68,
      vote_count: 25000,
      vote_average: 7.9,
      release_date: "1997-11-18",
      adult: false
    });

    let attempts = 0;
    const aiGenerator: OpenAiPuzzleGenerator = {
      async generatePuzzleFields() {
        attempts += 1;
        if (attempts === 1) {
          return {
            emoji_clue: "🚢🧊",
            hint_1: "Released in 1997",
            hint_2: "Directed by James Cameron",
            accepted_answers: ["Titanic"]
          };
        }

        return {
          emoji_clue: "🚢 🧊 ❤️",
          hint_1: "Released in 1997",
          hint_2: "Directed by James Cameron",
          accepted_answers: ["Titanic"]
        };
      }
    };

    const puzzle = await generateDailyPuzzleDocument({
      targetDate: new Date("2026-02-15T05:00:00Z"),
      tmdbFetcher,
      aiGenerator,
      maxAiAttempts: 3
    });

    expect(attempts).toBe(2);
    expect(puzzle.emoji_clue).toBe("🚢🧊❤️");
  });

  it("throws after max ai attempts when all candidates fail quality checks", async () => {
    const tmdbFetcher = async () => ({
      id: 597,
      title: "Titanic",
      overview: "A seventeen-year-old aristocrat falls in love.",
      popularity: 68,
      vote_count: 25000,
      vote_average: 7.9,
      release_date: "1997-11-18",
      adult: false
    });

    let attempts = 0;
    const aiGenerator: OpenAiPuzzleGenerator = {
      async generatePuzzleFields() {
        attempts += 1;
        return {
          emoji_clue: "🚢🧊",
          hint_1: "The Titanic sinks",
          hint_2: "Released in 1997",
          accepted_answers: ["Titanic"]
        };
      }
    };

    await expect(
      generateDailyPuzzleDocument({
        targetDate: new Date("2026-02-15T05:00:00Z"),
        tmdbFetcher,
        aiGenerator,
        maxAiAttempts: 2
      })
    ).rejects.toThrow(/failed to generate a quality puzzle after 2 attempts/i);
    expect(attempts).toBe(2);
  });

  it.each([0, -1, 2.5])(
    "throws when maxAiAttempts is invalid (%s)",
    async (maxAiAttempts) => {
      let fetchCalls = 0;
      const tmdbFetcher = async () => {
        fetchCalls += 1;
        return {
          id: 597,
          title: "Titanic",
          overview: "A seventeen-year-old aristocrat falls in love.",
          popularity: 68,
          vote_count: 25000,
          vote_average: 7.9,
          release_date: "1997-11-18",
          adult: false
        };
      };

      const aiGenerator: OpenAiPuzzleGenerator = {
        async generatePuzzleFields() {
          return {
            emoji_clue: "🚢 🧊 ❤️",
            hint_1: "Released in 1997",
            hint_2: "Directed by James Cameron",
            accepted_answers: ["Titanic"]
          };
        }
      };

      await expect(
        generateDailyPuzzleDocument({
          targetDate: new Date("2026-02-15T05:00:00Z"),
          tmdbFetcher,
          aiGenerator,
          maxAiAttempts
        })
      ).rejects.toThrow(/maxAiAttempts must be a positive integer/i);
      expect(fetchCalls).toBe(0);
    }
  );

  it("defaults to 3 ai attempts when maxAiAttempts is omitted", async () => {
    const tmdbFetcher = async () => ({
      id: 597,
      title: "Titanic",
      overview: "A seventeen-year-old aristocrat falls in love.",
      popularity: 68,
      vote_count: 25000,
      vote_average: 7.9,
      release_date: "1997-11-18",
      adult: false
    });

    let attempts = 0;
    const aiGenerator: OpenAiPuzzleGenerator = {
      async generatePuzzleFields() {
        attempts += 1;
        return {
          emoji_clue: "🚢🧊",
          hint_1: "Released in 1997",
          hint_2: "Directed by James Cameron",
          accepted_answers: ["Titanic"]
        };
      }
    };

    await expect(
      generateDailyPuzzleDocument({
        targetDate: new Date("2026-02-15T05:00:00Z"),
        tmdbFetcher,
        aiGenerator
      })
    ).rejects.toThrow(/failed to generate a quality puzzle after 3 attempts/i);
    expect(attempts).toBe(3);
  });

  it("generates quality-checked localizations under one stable puzzle id", async () => {
    const tmdbFetcher = async () => ({
      id: 8587,
      title: "The Lion King",
      overview: "A young lion returns home to become king.",
      popularity: 80,
      vote_count: 20000,
      vote_average: 8.0,
      release_date: "1994-06-24",
      adult: false
    });
    const localizationFetcher = async () => [
      { locale: "fr-FR" as const, title: "Le Roi Lion", overview: "Un jeune lion retrouve sa terre.", alternativeTitles: [] },
      { locale: "es-MX" as const, title: "El Rey León", overview: "Un joven heredero vuelve a casa.", alternativeTitles: [] },
      { locale: "pt-BR" as const, title: "O Rei Leão", overview: "Um jovem herdeiro volta para casa.", alternativeTitles: [] }
    ];
    const aiGenerator: OpenAiPuzzleGenerator = {
      async generatePuzzleFields(input) {
        const hints = {
          "fr-FR": ["Un jeune héritier retourne dans la savane", "Son oncle a pris sa place"],
          "es-MX": ["Un joven heredero regresa a la sabana", "Su tío tomó su lugar"],
          "pt-BR": ["Um jovem herdeiro retorna à savana", "Seu tio tomou seu lugar"]
        } as const;
        const localizedHints = input.locale ? hints[input.locale] : ["A young heir returns to the savanna", "His uncle took his place"];
        return {
          emoji_clue: "🦁👑🌅",
          hint_1: localizedHints[0],
          hint_2: localizedHints[1],
          accepted_answers: [input.title]
        };
      }
    };

    const puzzle = await generateDailyPuzzleDocument({
      targetDate: new Date("2026-02-15T05:00:00Z"),
      tmdbFetcher,
      localizationFetcher,
      aiGenerator
    });

    expect(puzzle.puzzle_id).toBe("2026-02-15");
    expect(puzzle.localizations?.["fr-FR"]?.title).toBe("Le Roi Lion");
    expect(puzzle.localizations?.["es-MX"]?.accepted_answers).toContain("the lion king");
    expect(puzzle.localizations?.["pt-BR"]?.accepted_answers).toContain("o rei leão");
  });
});
