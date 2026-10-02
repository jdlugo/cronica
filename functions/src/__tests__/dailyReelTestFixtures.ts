import { readFileSync } from "node:fs";
import {
  DAILY_REEL_LOCALES,
  DailyReelPrivateSchema,
  type DailyReelPrivate,
} from "../dailyReelSchema.js";
import type { DailyReelCandidate, DailyReelGeneratedPayload } from "../dailyReelGenerator.js";

const fixtureUrl = new URL(
  "../../../contracts/daily-reel/v1/fixtures/published-reel.json",
  import.meta.url,
);

export function makePrivateReel(): DailyReelPrivate {
  const reel = JSON.parse(readFileSync(fixtureUrl, "utf8")) as Record<string, unknown>;
  const localizedAnswers = {
    en: "Back to the Future",
    "fr-FR": "Retour vers le futur",
    "es-ES": "Regreso al futuro",
    "es-MX": "Volver al futuro",
    "pt-BR": "De Volta para o Futuro",
  } as const;
  const titleLengths = {
    en: 15,
    "fr-FR": 17,
    "es-ES": 15,
    "es-MX": 14,
    "pt-BR": 18,
  } as const;
  const threadReveals = {
    en: {
      title: "The Spielberg time loop",
      explanation: "Spielberg executive-produced Back to the Future; then you spotted his directing across Jurassic Park, Jaws, and E.T. before ordering The Terminator, The Matrix, and Inception through three decades of time-bending science fiction.",
    },
    "fr-FR": {
      title: "La boucle temporelle de Spielberg",
      explanation: "Spielberg a produit Retour vers le futur ; tu as ensuite reconnu sa réalisation avec Jurassic Park, Les Dents de la mer et E.T. avant de classer Terminator, Matrix et Inception sur trois décennies de science-fiction temporelle.",
    },
    "es-ES": {
      title: "El bucle temporal de Spielberg",
      explanation: "Spielberg produjo Regreso al futuro; después reconociste su dirección en Parque Jurásico, Tiburón y E.T. antes de ordenar Terminator, Matrix y Origen a través de tres décadas de ciencia ficción temporal.",
    },
    "es-MX": {
      title: "El bucle temporal de Spielberg",
      explanation: "Spielberg produjo Volver al futuro; después reconociste su dirección en Jurassic Park, Tiburón y E.T. antes de ordenar El exterminador, Matrix y El origen a través de tres décadas de ciencia ficción temporal.",
    },
    "pt-BR": {
      title: "O ciclo temporal de Spielberg",
      explanation: "Spielberg produziu De Volta para o Futuro; depois você reconheceu sua direção em Jurassic Park, Tubarão e E.T. antes de ordenar O Exterminador do Futuro, Matrix e A Origem por três décadas de ficção científica temporal.",
    },
  } as const;

  const answers = Object.fromEntries(
    DAILY_REEL_LOCALES.map((locale) => [
      locale,
      {
        decode: {
          acceptedAnswers: [localizedAnswers[locale]],
          titleLength: titleLengths[locale],
          hint: "A time-traveling car is central to the story.",
          revealTitle: localizedAnswers[locale],
          explanation: "The emojis point to reversing time, a car, and lightning.",
        },
        connect: {
          correctChoiceId: "c1",
          hint: "Think about who worked behind the camera.",
          explanation: "Steven Spielberg directed all three films.",
        },
        arrange: {
          correctOrder: ["tmdb:218", "tmdb:603", "tmdb:27205"],
          hint: "One film is from the 1980s.",
          explanation: "The films were released in 1984, 1999, and 2010.",
        },
        threadReveal: threadReveals[locale],
      },
    ]),
  );
  return DailyReelPrivateSchema.parse({ reel, answers });
}

export function makeGeneratedPayload(): DailyReelGeneratedPayload {
  return {
    privateReel: makePrivateReel(),
    movieFacts: [
      movieFact("tmdb:329", 329, "1993-06-11", ["person:488"]),
      movieFact("tmdb:578", 578, "1975-06-20", ["person:488"]),
      movieFact("tmdb:601", 601, "1982-06-11", ["person:488"]),
      movieFact("tmdb:218", 218, "1994-02-04", ["person:2710"]),
      movieFact("tmdb:603", 603, "1994-07-29", ["person:9340", "person:9339"]),
      movieFact("tmdb:27205", 27205, "1994-12-16", ["person:525"]),
      movieFact("tmdb:105", 105, "1985-07-03", ["person:24"]),
    ],
    connection: {
      kind: "director",
      key: "person:488",
      evidenceByMovieId: {
        "tmdb:329": "TMDb credits Steven Spielberg as director.",
        "tmdb:578": "TMDb credits Steven Spielberg as director.",
        "tmdb:601": "TMDb credits Steven Spielberg as director.",
      },
    },
    difficulty: { decode: "medium", connect: "easy", arrange: "hard" },
    safety: { isSafe: true, categories: [] },
  };
}

export function makeCandidate(overrides: Partial<DailyReelCandidate> = {}): DailyReelCandidate {
  const payload = makeGeneratedPayload();
  return {
    candidateId: "reel-fixture-candidate",
    generationKey: "fixture-generation",
    intendedPublicationId: "fixture-2026-08-28",
    state: "generated",
    privateReel: payload.privateReel,
    movieFacts: payload.movieFacts,
    connection: payload.connection,
    difficulty: payload.difficulty,
    safety: payload.safety,
    generatorVersion: "daily-reel-generator.v1",
    themeSeed: "Extraordinary journeys",
    createdAt: "2026-08-28T12:00:00.000Z",
    updatedAt: "2026-08-28T12:00:00.000Z",
    qualityReport: null,
    approvedVersionId: null,
    approvedAt: null,
    approvedBy: null,
    deniedAt: null,
    deniedBy: null,
    replacementQueued: false,
    ...overrides,
  };
}

export function clone<T>(value: T): T {
  return JSON.parse(JSON.stringify(value)) as T;
}

function movieFact(
  movieId: string,
  tmdbId: number,
  releaseDate: string,
  directorIds: string[],
) {
  return {
    movieId,
    tmdbId,
    releaseDate,
    directorIds,
    actorIds: [`actor:${tmdbId}`],
    genreIds: [12],
    franchiseId: null,
  };
}
