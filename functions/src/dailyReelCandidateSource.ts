import { readFile } from "node:fs/promises";
import { dirname, resolve } from "node:path";
import { z } from "zod";
import {
  DAILY_REEL_LOCALES,
  DailyReelPublicSchema,
} from "./dailyReelSchema.js";
import {
  DailyReelGeneratedPayloadSchema,
  type DailyReelGeneratedPayload,
  type DailyReelGenerationRequest,
} from "./dailyReelGenerator.js";

const CandidateSourceSchema = z
  .object({
    generationKey: z.string().trim().min(1).max(160),
    intendedPublicationId: z.string().trim().min(1).max(80),
    themeSeed: z.string().trim().min(1).max(160),
    publicReelTemplate: z.string().trim().min(1).max(260),
    contentVersion: z.string().trim().min(1).max(80),
    publicationWindow: z
      .object({
        availableAt: z.string().trim().min(1).max(40),
        expiresAt: z.string().trim().min(1).max(40),
      })
      .strict(),
    posterPaths: z.record(z.string().trim().min(1), z.string().regex(/^\/[A-Za-z0-9._-]+$/)),
    answers: z.unknown(),
    movieFacts: z.unknown(),
    connection: z.unknown(),
    difficulty: z.unknown(),
    safety: z.unknown(),
    recentMovieIds: z.array(z.string().trim().min(1)).default([]),
    recentThemeKeys: z.array(z.string().trim().min(1)).default([]),
  })
  .strict();

export interface LoadedDailyReelCandidateSource {
  request: DailyReelGenerationRequest;
  payload: DailyReelGeneratedPayload;
}

export async function loadDailyReelCandidateSource(
  sourcePath: string,
): Promise<LoadedDailyReelCandidateSource> {
  const absoluteSourcePath = resolve(sourcePath);
  const source = CandidateSourceSchema.parse(
    JSON.parse(await readFile(absoluteSourcePath, "utf8")),
  );
  const templatePath = resolve(dirname(absoluteSourcePath), source.publicReelTemplate);
  const reel = structuredClone(
    DailyReelPublicSchema.parse(JSON.parse(await readFile(templatePath, "utf8"))),
  );

  reel.publicationId = source.intendedPublicationId;
  reel.contentVersion = source.contentVersion;
  reel.publicationWindow = source.publicationWindow;
  for (const locale of DAILY_REEL_LOCALES) {
    for (const act of reel.localized[locale].acts) {
      if (!("films" in act)) continue;
      act.films = act.films.map((film) => ({
        ...film,
        posterPath: source.posterPaths[film.id] ?? film.posterPath,
      }));
    }
  }

  const payload = DailyReelGeneratedPayloadSchema.parse({
    privateReel: { reel, answers: source.answers },
    movieFacts: source.movieFacts,
    connection: source.connection,
    difficulty: source.difficulty,
    safety: source.safety,
  });
  return {
    request: {
      generationKey: source.generationKey,
      intendedPublicationId: source.intendedPublicationId,
      themeSeed: source.themeSeed,
      recentMovieIds: source.recentMovieIds,
      recentThemeKeys: source.recentThemeKeys,
    },
    payload,
  };
}
