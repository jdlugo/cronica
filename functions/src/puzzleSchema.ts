import { z } from "zod";

export const puzzleLocales = ["fr-FR", "es-MX", "pt-BR"] as const;
export type PuzzleLocale = (typeof puzzleLocales)[number];

const aiPuzzlePayloadSchema = z.object({
  emoji_clue: z.string().min(2),
  hint_1: z.string().min(8),
  hint_2: z.string().min(8),
  accepted_answers: z.array(z.string().min(1)).min(1)
});

const localizedPuzzleContentSchema = aiPuzzlePayloadSchema.extend({
  title: z.string().min(1)
});

const puzzleLocalizationsSchema = z.object({
  "fr-FR": localizedPuzzleContentSchema.optional(),
  "es-MX": localizedPuzzleContentSchema.optional(),
  "pt-BR": localizedPuzzleContentSchema.optional()
}).strict();

const dailyPuzzleDocumentSchema = z.object({
  date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
  puzzle_id: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
  media_type: z.literal("movie"),
  tmdb_id: z.number().int().positive(),
  title: z.string().min(1),
  emoji_clue: z.string().min(2),
  hint_1: z.string().min(8),
  hint_2: z.string().min(8),
  accepted_answers: z.array(z.string().min(1)).min(1),
  localizations: puzzleLocalizationsSchema.optional(),
  source: z.literal("ai+tmdb"),
  practice_eligible: z.literal(true),
  generated_at: z.string().datetime({ offset: true })
});

export type NormalizedAiPuzzlePayload = z.infer<typeof aiPuzzlePayloadSchema>;
export type LocalizedPuzzleContent = z.infer<typeof localizedPuzzleContentSchema>;
export type DailyPuzzleDocument = z.infer<typeof dailyPuzzleDocumentSchema>;

function normalizeAnswer(answer: string): string {
  return answer.trim().toLowerCase();
}

export function normalizeAiPuzzlePayload(payload: unknown): NormalizedAiPuzzlePayload {
  const parsed = aiPuzzlePayloadSchema.parse(payload);
  const acceptedAnswers = Array.from(
    new Set(parsed.accepted_answers.map(normalizeAnswer).filter((answer) => answer.length > 0))
  );

  if (acceptedAnswers.length === 0) {
    throw new Error("AI payload must include at least one accepted answer");
  }

  return {
    emoji_clue: parsed.emoji_clue.replace(/\s+/gu, ""),
    hint_1: parsed.hint_1.trim(),
    hint_2: parsed.hint_2.trim(),
    accepted_answers: acceptedAnswers
  };
}

export function validateDailyPuzzleDocument(document: unknown): DailyPuzzleDocument {
  return dailyPuzzleDocumentSchema.parse(document);
}
