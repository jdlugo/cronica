import { describe, expect, it } from "vitest";

import {
  assertPuzzleQuality,
  countGraphemes,
  normalizeTitleTokens
} from "../puzzleQuality.js";

describe("puzzle quality", () => {
  it("counts grapheme clusters for emoji clues", () => {
    expect(countGraphemes("👨‍👩‍👧‍👦🎬🔥")).toBe(3);
  });

  it("normalizes title tokens by removing punctuation and stop words", () => {
    expect(normalizeTitleTokens("The Lord of the Rings: The Return of the King")).toEqual([
      "lord",
      "rings",
      "return",
      "king"
    ]);
  });

  it("keeps short non-stopword title tokens while still filtering stop words", () => {
    expect(normalizeTitleTokens("Up")).toEqual(["up"]);
    expect(normalizeTitleTokens("It")).toEqual(["it"]);
    expect(normalizeTitleTokens("A An The")).toEqual([]);
  });

  it("uses locale-specific stop words without stripping meaningful accented tokens", () => {
    expect(normalizeTitleTokens("Le Fabuleux Destin d'Amélie Poulain", "fr-FR")).toEqual([
      "fabuleux",
      "destin",
      "damélie",
      "poulain"
    ]);
    expect(normalizeTitleTokens("El Laberinto del Fauno", "es-MX")).toEqual([
      "laberinto",
      "fauno"
    ]);
  });

  it("accepts puzzle when emoji clue has 3-5 graphemes and hints avoid title words", () => {
    expect(() =>
      assertPuzzleQuality({
        title: "Titanic",
        emojiClue: "🚢🧊❤️",
        hint1: "Released in 1997",
        hint2: "Directed by James Cameron",
        acceptedAnswers: ["titanic"]
      })
    ).not.toThrow();
  });

  it("rejects puzzle when either hint leaks normalized title tokens", () => {
    expect(() =>
      assertPuzzleQuality({
        title: "Titanic",
        emojiClue: "🚢🧊❤️",
        hint1: "Rose falls in love on TITANIC!",
        hint2: "Released in 1997",
        acceptedAnswers: ["titanic"]
      })
    ).toThrow(/hint contains title/i);
  });

  it("rejects puzzle when hint2 leaks normalized title tokens", () => {
    expect(() =>
      assertPuzzleQuality({
        title: "Titanic",
        emojiClue: "🚢🧊❤️",
        hint1: "Released in 1997",
        hint2: "The TITANIC hits an iceberg",
        acceptedAnswers: ["titanic"]
      })
    ).toThrow(/hint contains title token "titanic" in hint2/i);
  });

  it("rejects puzzle when short non-stopword title tokens leak into hints", () => {
    expect(() =>
      assertPuzzleQuality({
        title: "Up",
        emojiClue: "🎈🏠👴",
        hint1: "A widower sends his house up with balloons",
        hint2: "Released by Pixar in 2009",
        acceptedAnswers: ["up"]
      })
    ).toThrow(/hint contains title token "up" in hint1/i);
  });

  it("does not generate false positives for apostrophe titles with common contractions", () => {
    expect(() =>
      assertPuzzleQuality({
        title: "Schindler's List",
        emojiClue: "📜🕯️🏭",
        hint1: "It's set during World War II",
        hint2: "Directed by Steven Spielberg",
        acceptedAnswers: ["schindler's list"]
      })
    ).not.toThrow();
  });

  it("rejects puzzle when emoji clue has fewer than 3 graphemes", () => {
    expect(() =>
      assertPuzzleQuality({
        title: "Titanic",
        emojiClue: "🚢🧊",
        hint1: "Released in 1997",
        hint2: "Directed by James Cameron",
        acceptedAnswers: ["titanic"]
      })
    ).toThrow(/emoji clue must contain 3 to 5 graphemes/i);
  });

  it("rejects puzzle when emoji clue has more than 5 graphemes", () => {
    expect(() =>
      assertPuzzleQuality({
        title: "Titanic",
        emojiClue: "🚢🧊❤️🎬⭐🔥",
        hint1: "Released in 1997",
        hint2: "Directed by James Cameron",
        acceptedAnswers: ["titanic"]
      })
    ).toThrow(/emoji clue must contain 3 to 5 graphemes/i);
  });

  it("rejects puzzle when canonical title is missing from accepted answers", () => {
    expect(() =>
      assertPuzzleQuality({
        title: "Spider-Man: No Way Home",
        emojiClue: "🕷️🌀🏠",
        hint1: "Released in 2021",
        hint2: "Peter asks for a magical reset",
        acceptedAnswers: ["spider man", "no way home"]
      })
    ).toThrow(/accepted answers must include canonical title/i);
  });
});
