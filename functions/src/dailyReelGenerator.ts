import { createHash } from "node:crypto";
import { z } from "zod";
import {
  DAILY_REEL_LOCALES,
  DailyReelPrivateSchema,
  type DailyReelPrivate,
} from "./dailyReelSchema.js";

export const DAILY_REEL_GENERATOR_VERSION = "daily-reel-generator.v1" as const;

export const DailyReelMovieFactSchema = z
  .object({
    movieId: z.string().trim().min(1).max(80),
    tmdbId: z.number().int().positive(),
    releaseDate: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
    directorIds: z.array(z.string().trim().min(1).max(80)),
    actorIds: z.array(z.string().trim().min(1).max(80)),
    genreIds: z.array(z.number().int().positive()),
    franchiseId: z.string().trim().min(1).max(80).nullable(),
  })
  .strict();

export type DailyReelMovieFact = z.infer<typeof DailyReelMovieFactSchema>;

const factualConnectionSchema = z.object({
  key: z.string().trim().min(1).max(100),
  evidenceByMovieId: z.record(z.string(), z.string().trim().min(1).max(320)),
});

export const DailyReelConnectionSchema = z.discriminatedUnion("kind", [
  factualConnectionSchema.extend({ kind: z.literal("actor") }).strict(),
  factualConnectionSchema.extend({ kind: z.literal("director") }).strict(),
  factualConnectionSchema.extend({ kind: z.literal("franchise") }).strict(),
  factualConnectionSchema.extend({ kind: z.literal("genre") }).strict(),
  factualConnectionSchema.extend({ kind: z.literal("theme") }).strict(),
]);

export type DailyReelConnection = z.infer<typeof DailyReelConnectionSchema>;

export const DailyReelDifficultySchema = z
  .object({
    decode: z.enum(["easy", "medium", "hard"]),
    connect: z.enum(["easy", "medium", "hard"]),
    arrange: z.enum(["easy", "medium", "hard"]),
  })
  .strict();

export type DailyReelDifficulty = z.infer<typeof DailyReelDifficultySchema>;

export const DailyReelGeneratedPayloadSchema = z
  .object({
    privateReel: DailyReelPrivateSchema,
    movieFacts: z.array(DailyReelMovieFactSchema).min(7).max(9),
    connection: DailyReelConnectionSchema,
    difficulty: DailyReelDifficultySchema,
    safety: z
      .object({
        isSafe: z.boolean(),
        categories: z.array(z.string().trim().min(1).max(80)).max(20),
      })
      .strict(),
  })
  .strict();

export type DailyReelGeneratedPayload = z.infer<typeof DailyReelGeneratedPayloadSchema>;

export type DailyReelCandidateState =
  | "generated"
  | "validating"
  | "awaitingApproval"
  | "approved"
  | "denied"
  | "rejected"
  | "scheduled"
  | "published";

export interface DailyReelCandidate {
  candidateId: string;
  generationKey: string;
  intendedPublicationId: string;
  state: DailyReelCandidateState;
  privateReel: DailyReelPrivate;
  movieFacts: DailyReelMovieFact[];
  connection: DailyReelConnection;
  difficulty: DailyReelDifficulty;
  safety: { isSafe: boolean; categories: string[] };
  generatorVersion: string;
  themeSeed: string;
  createdAt: string;
  updatedAt: string;
  qualityReport: unknown | null;
  approvedVersionId: string | null;
  approvedAt: string | null;
  approvedBy: string | null;
  deniedAt: string | null;
  deniedBy: string | null;
  replacementQueued: boolean;
}

export interface DailyReelGenerationRequest {
  generationKey: string;
  intendedPublicationId: string;
  themeSeed: string;
  recentMovieIds: string[];
  recentThemeKeys: string[];
}

export interface DailyReelDraftProvider {
  generate(input: {
    intendedPublicationId: string;
    themeSeed: string;
    locales: readonly string[];
    recentMovieIds: readonly string[];
    recentThemeKeys: readonly string[];
  }): Promise<unknown>;
}

export class DailyReelGenerator {
  constructor(
    private readonly provider: DailyReelDraftProvider,
    private readonly now: () => Date = () => new Date(),
  ) {}

  async generate(request: DailyReelGenerationRequest): Promise<DailyReelCandidate> {
    const generationKey = request.generationKey.trim();
    const intendedPublicationId = request.intendedPublicationId.trim();
    const themeSeed = request.themeSeed.trim();
    if (!generationKey || !intendedPublicationId || !themeSeed) {
      throw new Error("Generation key, publication ID, and theme seed are required");
    }

    const rawPayload = await this.provider.generate({
      intendedPublicationId,
      themeSeed,
      locales: DAILY_REEL_LOCALES,
      recentMovieIds: request.recentMovieIds,
      recentThemeKeys: request.recentThemeKeys,
    });
    const payload = DailyReelGeneratedPayloadSchema.parse(rawPayload);
    if (payload.privateReel.reel.publicationId !== intendedPublicationId) {
      throw new Error("Generated Reel publication ID does not match the requested publication");
    }

    const timestamp = this.now().toISOString();
    const candidateId = candidateID(generationKey, payload.privateReel.reel.contentVersion);
    return {
      candidateId,
      generationKey,
      intendedPublicationId,
      state: "generated",
      privateReel: payload.privateReel,
      movieFacts: payload.movieFacts,
      connection: payload.connection,
      difficulty: payload.difficulty,
      safety: payload.safety,
      generatorVersion: DAILY_REEL_GENERATOR_VERSION,
      themeSeed,
      createdAt: timestamp,
      updatedAt: timestamp,
      qualityReport: null,
      approvedVersionId: null,
      approvedAt: null,
      approvedBy: null,
      deniedAt: null,
      deniedBy: null,
      replacementQueued: false,
    };
  }
}

function candidateID(generationKey: string, contentVersion: string): string {
  const digest = createHash("sha256")
    .update(`${generationKey}\u0000${contentVersion}`)
    .digest("hex")
    .slice(0, 24);
  return `reel-${digest}`;
}
