import { describe, expect, it } from "vitest";

import { buildPuzzlePrompts } from "../openaiClient.js";

describe("OpenAI puzzle prompts", () => {
  it("requests accessible, literal emoji clues and useful hints", () => {
    const prompts = buildPuzzlePrompts({
      title: "Finding Nemo",
      overview: "A clownfish crosses the ocean to find his missing son.",
      releaseDate: "2003-05-30"
    });

    expect(prompts.system).toContain("very easy");
    expect(prompts.system).toContain("globally recognizable");
    expect(prompts.user).toContain("literal");
    expect(prompts.user).toContain("central premise");
    expect(prompts.user).toContain("nearly decisive");
    expect(prompts.user).toContain("Do not use minor scenes");
  });

  it("requests locale-native hints and includes known release-title aliases", () => {
    const prompts = buildPuzzlePrompts({
      title: "Carros",
      canonicalTitle: "Cars",
      overview: "Um carro de corrida descobre a amizade.",
      releaseDate: "2006-06-08",
      locale: "pt-BR",
      acceptedTitleAliases: ["Carros", "Cars"]
    });

    expect(prompts.system).toContain("Brazilian Portuguese");
    expect(prompts.user).toContain("Canonical title: Cars");
    expect(prompts.user).toContain("Carros | Cars");
  });
});
