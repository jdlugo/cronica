import {
  normalizeAiPuzzlePayload,
  validateDailyPuzzleDocument,
  type DailyPuzzleDocument,
  type PuzzleLocale
} from "./puzzleSchema.js";
import { assertPuzzleQuality } from "./puzzleQuality.js";
import type { TmdbLocalizedMovieResult, TmdbMovieResult } from "./tmdb.js";

export interface PuzzleGenerationInput {
  title: string;
  overview: string;
  releaseDate: string;
  locale?: PuzzleLocale;
  canonicalTitle?: string;
  acceptedTitleAliases?: string[];
}

export interface OpenAiPuzzleGenerator {
  generatePuzzleFields(input: PuzzleGenerationInput): Promise<unknown>;
}

interface GenerateDailyPuzzleOptions {
  targetDate: Date;
  tmdbFetcher: () => Promise<TmdbMovieResult>;
  localizationFetcher?: (movie: TmdbMovieResult) => Promise<TmdbLocalizedMovieResult[]>;
  aiGenerator: OpenAiPuzzleGenerator;
  maxAiAttempts?: number;
}

function dayStamp(date: Date): string {
  return date.toISOString().slice(0, 10);
}

function toCanonicalAnswer(value: string): string {
  return value.trim().toLowerCase();
}

function splitGraphemes(value: string): string[] {
  const segmenter = new Intl.Segmenter("en", { granularity: "grapheme" });
  return Array.from(segmenter.segment(value), (segment) => segment.segment).filter((segment) => segment.trim().length > 0);
}

async function generateQualityContent(input: {
  title: string;
  canonicalTitle: string;
  overview: string;
  releaseDate: string;
  locale?: PuzzleLocale;
  acceptedTitleAliases: string[];
  aiGenerator: OpenAiPuzzleGenerator;
  maxAiAttempts: number;
}) {
  let lastError: unknown;
  for (let attempt = 1; attempt <= input.maxAiAttempts; attempt += 1) {
    try {
      const aiOutput = await input.aiGenerator.generatePuzzleFields({
        title: input.title,
        canonicalTitle: input.canonicalTitle,
        overview: input.overview,
        releaseDate: input.releaseDate,
        locale: input.locale,
        acceptedTitleAliases: input.acceptedTitleAliases
      });
      const normalizedPayload = normalizeAiPuzzlePayload(aiOutput);
      const acceptedAnswers = Array.from(
        new Set(
          [...normalizedPayload.accepted_answers, ...input.acceptedTitleAliases]
            .map(toCanonicalAnswer)
            .filter((answer) => answer.length > 0)
        )
      );

      assertPuzzleQuality({
        title: input.title,
        emojiClue: normalizedPayload.emoji_clue,
        hint1: normalizedPayload.hint_1,
        hint2: normalizedPayload.hint_2,
        acceptedAnswers,
        locale: input.locale
      });

      return { ...normalizedPayload, accepted_answers: acceptedAnswers };
    } catch (error) {
      lastError = error;
    }
  }

  const localeLabel = input.locale ? ` for ${input.locale}` : "";
  const lastErrorMessage = lastError instanceof Error ? lastError.message : String(lastError);
  throw new Error(
    `Failed to generate a quality puzzle${localeLabel} after ${input.maxAiAttempts} attempts: ${lastErrorMessage}`
  );
}

export function formatPushBodyFromEmojiClue(emojiClue: string): string {
  const graphemes = splitGraphemes(emojiClue.replace(/\s+/gu, ""));
  const choices = graphemes.slice(0, 3);

  while (choices.length < 3) {
    choices.push("❓");
  }

  return `${choices[0]} + ${choices[1]} + ${choices[2]} = ______`;
}

export async function generateDailyPuzzleDocument(
  options: GenerateDailyPuzzleOptions
): Promise<DailyPuzzleDocument> {
  const maxAiAttempts = options.maxAiAttempts ?? 3;
  if (!Number.isInteger(maxAiAttempts) || maxAiAttempts < 1) {
    throw new Error(`maxAiAttempts must be a positive integer, received ${maxAiAttempts}`);
  }
  const candidate = await options.tmdbFetcher();
  const canonicalContent = await generateQualityContent({
    title: candidate.title,
    canonicalTitle: candidate.title,
    overview: candidate.overview,
    releaseDate: candidate.release_date,
    acceptedTitleAliases: [candidate.title],
    aiGenerator: options.aiGenerator,
    maxAiAttempts
  });

  const localizations: NonNullable<DailyPuzzleDocument["localizations"]> = {};
  if (options.localizationFetcher) {
    const localizedMovies = await options.localizationFetcher(candidate);
    for (const localizedMovie of localizedMovies) {
      const acceptedTitleAliases = [
        localizedMovie.title,
        candidate.title,
        ...localizedMovie.alternativeTitles
      ];
      const localizedContent = await generateQualityContent({
        title: localizedMovie.title,
        canonicalTitle: candidate.title,
        overview: localizedMovie.overview,
        releaseDate: candidate.release_date,
        locale: localizedMovie.locale,
        acceptedTitleAliases,
        aiGenerator: options.aiGenerator,
        maxAiAttempts
      });
      localizations[localizedMovie.locale] = {
        title: localizedMovie.title,
        emoji_clue: localizedContent.emoji_clue,
        hint_1: localizedContent.hint_1,
        hint_2: localizedContent.hint_2,
        accepted_answers: localizedContent.accepted_answers
      };
    }
  }

  const document: DailyPuzzleDocument = {
    date: dayStamp(options.targetDate),
    puzzle_id: dayStamp(options.targetDate),
    media_type: "movie",
    tmdb_id: candidate.id,
    title: candidate.title,
    emoji_clue: canonicalContent.emoji_clue,
    hint_1: canonicalContent.hint_1,
    hint_2: canonicalContent.hint_2,
    accepted_answers: canonicalContent.accepted_answers,
    ...(Object.keys(localizations).length > 0 ? { localizations } : {}),
    source: "ai+tmdb",
    practice_eligible: true,
    generated_at: options.targetDate.toISOString()
  };

  return validateDailyPuzzleDocument(document);
}
