import OpenAI from "openai";

import type { OpenAiPuzzleGenerator, PuzzleGenerationInput } from "./generator.js";

const outputSchema = {
  type: "object",
  additionalProperties: false,
  required: ["emoji_clue", "hint_1", "hint_2", "accepted_answers"],
  properties: {
    emoji_clue: { type: "string" },
    hint_1: { type: "string" },
    hint_2: { type: "string" },
    accepted_answers: {
      type: "array",
      items: { type: "string" },
      minItems: 1
    }
  }
} as const;

const SYSTEM_PROMPT = [
  "You generate one very easy daily movie emoji puzzle.",
  "The movie must be globally recognizable to a broad casual audience.",
  "Prefer obvious fun over cleverness or ambiguity.",
  "Never output obscure or niche titles.",
  "Return only JSON that matches the schema."
].join(" ");

const localeLanguages = {
  "fr-FR": "French for France",
  "es-MX": "Mexican Spanish",
  "pt-BR": "Brazilian Portuguese"
} as const;

export function buildPuzzlePrompts(input: PuzzleGenerationInput): { system: string; user: string } {
  const languageInstruction = input.locale
    ? `Write both hints and accepted answer aliases in ${localeLanguages[input.locale]}.`
    : "Write both hints and accepted answer aliases in English.";
  const user = [
    `Movie title: ${input.title}`,
    ...(input.canonicalTitle && input.canonicalTitle !== input.title
      ? [`Canonical title: ${input.canonicalTitle}`]
      : []),
    ...(input.acceptedTitleAliases?.length
      ? [`Known release-title aliases: ${input.acceptedTitleAliases.join(" | ")}`]
      : []),
    `Release date: ${input.releaseDate}`,
    `Overview: ${input.overview}`,
    languageInstruction,
    "Create a 3-5 emoji clue using literal title concepts, iconic characters, or the central premise.",
    "At least two emojis should be direct, obvious associations with the answer.",
    "Do not use minor scenes, actor references, abstract symbolism, or details only fans would recognize.",
    "Make hint_1 immediately useful and make hint_2 nearly decisive without saying the title.",
    "Include common shortened titles and punctuation variants in accepted_answers.",
    "Hints must not contain the movie title."
  ].join("\n");

  return { system: `${SYSTEM_PROMPT} ${languageInstruction}`, user };
}

export class OpenAiStructuredPuzzleGenerator implements OpenAiPuzzleGenerator {
  private readonly client: OpenAI;
  private readonly model: string;

  constructor(apiKey: string, model = "gpt-4.1-mini") {
    this.client = new OpenAI({ apiKey });
    this.model = model;
  }

  async generatePuzzleFields(input: PuzzleGenerationInput): Promise<unknown> {
    const prompts = buildPuzzlePrompts(input);

    const response = await this.client.responses.create({
      model: this.model,
      input: [
        {
          role: "system",
          content: [{ type: "input_text", text: prompts.system }]
        },
        {
          role: "user",
          content: [{ type: "input_text", text: prompts.user }]
        }
      ],
      text: {
        format: {
          type: "json_schema",
          name: "daily_puzzle_fields",
          schema: outputSchema,
          strict: true
        }
      }
    } as never);

    const outputText = response.output_text?.trim();
    if (!outputText) {
      throw new Error("OpenAI response did not contain output_text");
    }

    return JSON.parse(outputText);
  }
}
