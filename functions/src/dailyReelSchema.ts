import { z } from "zod";

export const DAILY_REEL_CONTRACT_VERSION = "daily-reel.v1" as const;
export const DAILY_REEL_SESSION_VERSION = "daily-reel-session.v1" as const;
export const DAILY_REEL_SCORING_VERSION = "daily-reel-score.v1" as const;
export const DAILY_REEL_EXPERIENCE_VERSION = "daily-reel-experience.v1" as const;

export const DAILY_REEL_LOCALES = [
  "en",
  "fr-FR",
  "es-ES",
  "es-MX",
  "pt-BR",
] as const;

export type DailyReelLocale = (typeof DAILY_REEL_LOCALES)[number];

const nonEmptyString = (maximum: number) => z.string().trim().min(1).max(maximum);

export const DailyReelActRoleSchema = z.enum(["decode", "connect", "arrange"]);
export const DailyReelAssistKindSchema = z.enum(["titleLength", "hint"]);

export const DailyReelAssistOptionSchema = z
  .object({
    id: nonEmptyString(40),
    kind: DailyReelAssistKindSchema,
    label: nonEmptyString(80),
    scoreImpact: z.union([z.literal(0), z.literal(1)]),
  })
  .strict();

export const DailyReelFilmSchema = z
  .object({
    id: nonEmptyString(80),
    title: nonEmptyString(120),
    posterPath: z.string().max(240).nullable(),
  })
  .strict();

export const DailyReelChoiceSchema = z
  .object({
    id: nonEmptyString(40),
    label: nonEmptyString(120),
  })
  .strict();

export const DailyReelDecodeActSchema = z
  .object({
    id: nonEmptyString(80),
    role: z.literal("decode"),
    prompt: nonEmptyString(160),
    emoji: z.array(nonEmptyString(24)).min(2).max(8),
    assistOptions: z.array(DailyReelAssistOptionSchema).min(1).max(3),
  })
  .strict();

export const DailyReelConnectActSchema = z
  .object({
    id: nonEmptyString(80),
    role: z.literal("connect"),
    prompt: nonEmptyString(160),
    films: z.array(DailyReelFilmSchema).length(3),
    choices: z.array(DailyReelChoiceSchema).length(4),
    assistOptions: z.array(DailyReelAssistOptionSchema).min(1).max(2),
  })
  .strict();

export const DailyReelArrangeActSchema = z
  .object({
    id: nonEmptyString(80),
    role: z.literal("arrange"),
    prompt: nonEmptyString(160),
    films: z.array(DailyReelFilmSchema).length(3),
    assistOptions: z.array(DailyReelAssistOptionSchema).min(1).max(2),
  })
  .strict();

export const DailyReelActSchema = z.discriminatedUnion("role", [
  DailyReelDecodeActSchema,
  DailyReelConnectActSchema,
  DailyReelArrangeActSchema,
]);

export const DailyReelLocalizedContentSchema = z
  .object({
    theme: nonEmptyString(100),
    shareText: nonEmptyString(180),
    acts: z.tuple([
      DailyReelDecodeActSchema,
      DailyReelConnectActSchema,
      DailyReelArrangeActSchema,
    ]),
  })
  .strict();

const localizedContentMapSchema = z
  .object({
    en: DailyReelLocalizedContentSchema,
    "fr-FR": DailyReelLocalizedContentSchema,
    "es-ES": DailyReelLocalizedContentSchema,
    "es-MX": DailyReelLocalizedContentSchema,
    "pt-BR": DailyReelLocalizedContentSchema,
  })
  .strict();

export const DailyReelPublicSchema = z
  .object({
    contractVersion: z.literal(DAILY_REEL_CONTRACT_VERSION),
    publicationId: nonEmptyString(80),
    contentVersion: nonEmptyString(80),
    scoringVersion: z.literal(DAILY_REEL_SCORING_VERSION),
    publicationWindow: z
      .object({
        availableAt: nonEmptyString(40),
        expiresAt: nonEmptyString(40),
      })
      .strict(),
    defaultLocale: z.literal("en"),
    supportedLocales: z.tuple([
      z.literal("en"),
      z.literal("fr-FR"),
      z.literal("es-ES"),
      z.literal("es-MX"),
      z.literal("pt-BR"),
    ]),
    scoring: z
      .object({
        maxScore: z.literal(300),
        perActMax: z.literal(100),
        maxIncorrectAttemptsPerAct: z.literal(3),
      })
      .strict(),
    localized: localizedContentMapSchema,
  })
  .strict()
  .superRefine((reel, context) => {
    const availableAt = Date.parse(reel.publicationWindow.availableAt);
    const expiresAt = Date.parse(reel.publicationWindow.expiresAt);
    if (!Number.isFinite(availableAt) || !Number.isFinite(expiresAt) || expiresAt <= availableAt) {
      context.addIssue({
        code: "custom",
        path: ["publicationWindow"],
        message: "Publication window must contain valid increasing timestamps",
      });
    }

    for (const locale of DAILY_REEL_LOCALES) {
      const content = reel.localized[locale];
      const actIds = content.acts.map((act) => act.id);
      if (new Set(actIds).size !== actIds.length) {
        context.addIssue({
          code: "custom",
          path: ["localized", locale, "acts"],
          message: "Act IDs must be unique within a locale",
        });
      }

      const connect = content.acts[1];
      const connectFilmIds = connect.films.map((film) => film.id);
      const choiceIds = connect.choices.map((choice) => choice.id);
      if (new Set(connectFilmIds).size !== connectFilmIds.length) {
        context.addIssue({
          code: "custom",
          path: ["localized", locale, "acts", 1, "films"],
          message: "Connect films must be distinct",
        });
      }
      if (new Set(choiceIds).size !== choiceIds.length) {
        context.addIssue({
          code: "custom",
          path: ["localized", locale, "acts", 1, "choices"],
          message: "Connect choice IDs must be distinct",
        });
      }

      const arrangeFilmIds = content.acts[2].films.map((film) => film.id);
      if (new Set(arrangeFilmIds).size !== arrangeFilmIds.length) {
        context.addIssue({
          code: "custom",
          path: ["localized", locale, "acts", 2, "films"],
          message: "Arrange films must be distinct",
        });
      }
    }
  });

const DailyReelPrivateDecodeSchema = z
  .object({
    acceptedAnswers: z.array(nonEmptyString(120)).min(1).max(20),
    titleLength: z.number().int().positive().max(120),
    hint: nonEmptyString(240),
    revealTitle: nonEmptyString(120),
    explanation: nonEmptyString(320),
  })
  .strict();

const DailyReelPrivateConnectSchema = z
  .object({
    correctChoiceId: nonEmptyString(40),
    hint: nonEmptyString(240),
    explanation: nonEmptyString(320),
  })
  .strict();

const DailyReelPrivateArrangeSchema = z
  .object({
    correctOrder: z.tuple([nonEmptyString(80), nonEmptyString(80), nonEmptyString(80)]),
    hint: nonEmptyString(240),
    explanation: nonEmptyString(320),
  })
  .strict();

const DailyReelThreadRevealSchema = z
  .object({
    title: nonEmptyString(120),
    explanation: nonEmptyString(480),
  })
  .strict();

const DailyReelPrivateLocaleSchema = z
  .object({
    decode: DailyReelPrivateDecodeSchema,
    connect: DailyReelPrivateConnectSchema,
    arrange: DailyReelPrivateArrangeSchema,
    threadReveal: DailyReelThreadRevealSchema.optional(),
  })
  .strict();

const privateLocaleMapSchema = z
  .object({
    en: DailyReelPrivateLocaleSchema,
    "fr-FR": DailyReelPrivateLocaleSchema,
    "es-ES": DailyReelPrivateLocaleSchema,
    "es-MX": DailyReelPrivateLocaleSchema,
    "pt-BR": DailyReelPrivateLocaleSchema,
  })
  .strict();

export const DailyReelPrivateSchema = z
  .object({
    reel: DailyReelPublicSchema,
    answers: privateLocaleMapSchema,
  })
  .strict()
  .superRefine((value, context) => {
    for (const locale of DAILY_REEL_LOCALES) {
      const publicContent = value.reel.localized[locale];
      const privateContent = value.answers[locale];

      const normalizedAnswers = privateContent.decode.acceptedAnswers.map((answer) =>
        answer.normalize("NFKC").trim().toLocaleLowerCase(locale),
      );
      if (new Set(normalizedAnswers).size !== normalizedAnswers.length) {
        context.addIssue({
          code: "custom",
          path: ["answers", locale, "decode", "acceptedAnswers"],
          message: "Accepted answers must be unique after normalization",
        });
      }

      const choiceIds = new Set(publicContent.acts[1].choices.map((choice) => choice.id));
      if (!choiceIds.has(privateContent.connect.correctChoiceId)) {
        context.addIssue({
          code: "custom",
          path: ["answers", locale, "connect", "correctChoiceId"],
          message: "Correct Connect choice must exist in the public projection",
        });
      }

      const filmIds = new Set(publicContent.acts[2].films.map((film) => film.id));
      const correctOrder = privateContent.arrange.correctOrder;
      if (new Set(correctOrder).size !== 3 || correctOrder.some((filmId) => !filmIds.has(filmId))) {
        context.addIssue({
          code: "custom",
          path: ["answers", locale, "arrange", "correctOrder"],
          message: "Arrange order must contain each public film exactly once",
        });
      }
    }
  });

export const DailyReelActProgressSchema = z
  .object({
    actId: nonEmptyString(80),
    role: DailyReelActRoleSchema,
    status: z.enum(["playing", "solved", "revealed", "exhausted"]),
    incorrectAttempts: z.number().int().min(0).max(3),
    scoreAffectingClues: z.number().int().nonnegative(),
    requestedClueIds: z.array(nonEmptyString(40)).refine((ids) => new Set(ids).size === ids.length),
    score: z.number().int().min(0).max(100).nullable(),
  })
  .strict();

export const DailyReelSessionStateSchema = z
  .object({
    contractVersion: z.literal(DAILY_REEL_SESSION_VERSION),
    sessionId: nonEmptyString(100),
    publicationId: nonEmptyString(80),
    contentVersion: nonEmptyString(80),
    scoringVersion: z.literal(DAILY_REEL_SCORING_VERSION),
    configId: nonEmptyString(100),
    mode: z.enum(["daily", "challenge", "encore", "practice"]),
    status: z.enum(["active", "completed"]),
    currentActIndex: z.number().int().min(0).max(3),
    acts: z.tuple([
      DailyReelActProgressSchema.extend({ role: z.literal("decode") }),
      DailyReelActProgressSchema.extend({ role: z.literal("connect") }),
      DailyReelActProgressSchema.extend({ role: z.literal("arrange") }),
    ]),
    totalScore: z.number().int().min(0).max(300),
    completedAt: z.string().nullable(),
  })
  .strict();

export const DailyReelExperienceConfigSchema = z
  .object({
    configVersion: z.literal(DAILY_REEL_EXPERIENCE_VERSION),
    configId: nonEmptyString(100),
    scoringVersion: z.literal(DAILY_REEL_SCORING_VERSION),
    maxIncorrectAttemptsPerAct: z.literal(3),
    actOrder: z.tuple([
      z.literal("decode"),
      z.literal("connect"),
      z.literal("arrange"),
    ]),
    assistance: z
      .object({
        titleLength: z
          .object({ enabled: z.boolean(), scoreImpact: z.literal(0) })
          .strict(),
        standardHint: z
          .object({ enabled: z.boolean(), scoreImpact: z.literal(1) })
          .strict(),
      })
      .strict(),
    results: z
      .object({
        rematchProminence: z.literal("primary"),
        pickTonightEnabled: z.boolean(),
      })
      .strict(),
    festival: z
      .object({
        targetDistinctReels: z.literal(5),
        encoreRewardCount: z.literal(1),
      })
      .strict(),
  })
  .strict();

export type DailyReelPublic = z.infer<typeof DailyReelPublicSchema>;
export type DailyReelPrivate = z.infer<typeof DailyReelPrivateSchema>;
export type DailyReelSessionState = z.infer<typeof DailyReelSessionStateSchema>;
export type DailyReelExperienceConfig = z.infer<typeof DailyReelExperienceConfigSchema>;
