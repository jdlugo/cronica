import { readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";
import {
  DAILY_REEL_LOCALES,
  DailyReelPrivateSchema,
  DailyReelPublicSchema,
} from "../dailyReelSchema.js";

const fixtureUrl = new URL(
  "../../../contracts/daily-reel/v1/fixtures/published-reel.json",
  import.meta.url,
);

function loadFixture(): Record<string, unknown> {
  return JSON.parse(readFileSync(fixtureUrl, "utf8")) as Record<string, unknown>;
}

function deepClone<T>(value: T): T {
  return JSON.parse(JSON.stringify(value)) as T;
}

describe("DailyReelPublicSchema", () => {
  it("accepts the shared five-locale published projection", () => {
    const reel = DailyReelPublicSchema.parse(loadFixture());

    expect(Object.keys(reel.localized)).toEqual([...DAILY_REEL_LOCALES]);
    for (const locale of DAILY_REEL_LOCALES) {
      expect(reel.localized[locale].acts.map((act) => act.role)).toEqual([
        "decode",
        "connect",
        "arrange",
      ]);
    }
  });

  it("rejects a publication missing Spain Spanish", () => {
    const fixture = loadFixture();
    const localized = fixture.localized as Record<string, unknown>;
    delete localized["es-ES"];

    expect(() => DailyReelPublicSchema.parse(fixture)).toThrow();
  });

  it("rejects answer truth added to a public act", () => {
    const fixture = loadFixture();
    const localized = fixture.localized as Record<string, { acts: Array<Record<string, unknown>> }>;
    localized.en.acts[1].correctChoiceId = "c1";

    expect(() => DailyReelPublicSchema.parse(fixture)).toThrow();
  });

  it("contains no private answer keys", () => {
    const forbidden = new Set([
      "acceptedAnswers",
      "answer",
      "answers",
      "correctChoiceId",
      "correctOrder",
      "explanation",
      "hint",
      "revealTitle",
      "titleLength",
    ]);
    const found: string[] = [];

    const visit = (value: unknown): void => {
      if (Array.isArray(value)) {
        value.forEach(visit);
        return;
      }
      if (value && typeof value === "object") {
        for (const [key, child] of Object.entries(value)) {
          if (forbidden.has(key)) {
            found.push(key);
          }
          visit(child);
        }
      }
    };

    visit(loadFixture());
    expect(found).toEqual([]);
  });
});

describe("DailyReelPrivateSchema", () => {
  const answersByLocale = {
    en: ["Back to the Future"],
    "fr-FR": ["Retour vers le futur"],
    "es-ES": ["Regreso al futuro"],
    "es-MX": ["Volver al futuro"],
    "pt-BR": ["De Volta para o Futuro"],
  } as const;

  function privateFixture(): Record<string, unknown> {
    const answers = Object.fromEntries(
      DAILY_REEL_LOCALES.map((locale) => [
        locale,
        {
          decode: {
            acceptedAnswers: [...answersByLocale[locale]],
            titleLength: answersByLocale[locale][0].replaceAll(" ", "").length,
            hint: "A time-traveling car is central to the story.",
            revealTitle: answersByLocale[locale][0],
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
        },
      ]),
    );
    return { reel: deepClone(loadFixture()), answers };
  }

  it("accepts private answer truth when it references public choices and films", () => {
    expect(() => DailyReelPrivateSchema.parse(privateFixture())).not.toThrow();
  });

  it("rejects a correct Connect choice not present in the public projection", () => {
    const fixture = privateFixture();
    const answers = fixture.answers as Record<string, { connect: { correctChoiceId: string } }>;
    answers.en.connect.correctChoiceId = "not-a-choice";

    expect(() => DailyReelPrivateSchema.parse(fixture)).toThrow();
  });

  it("rejects an Arrange order that omits a public film", () => {
    const fixture = privateFixture();
    const answers = fixture.answers as Record<string, { arrange: { correctOrder: string[] } }>;
    answers.en.arrange.correctOrder = ["tmdb:218", "tmdb:603", "tmdb:603"];

    expect(() => DailyReelPrivateSchema.parse(fixture)).toThrow();
  });
});
