import {
  DAILY_REEL_LOCALES,
  DailyReelPrivateSchema,
  type DailyReelLocale,
} from "./dailyReelSchema.js";
import type {
  DailyReelCandidate,
  DailyReelConnection,
  DailyReelDifficulty,
  DailyReelMovieFact,
} from "./dailyReelGenerator.js";

export const DAILY_REEL_QUALITY_VERSION = "daily-reel-quality.v1" as const;

export type DailyReelQualitySeverity = "error" | "warning";

export interface DailyReelQualityFinding {
  code: string;
  severity: DailyReelQualitySeverity;
  message: string;
  locale?: DailyReelLocale;
  actRole?: "decode" | "connect" | "arrange";
}

export interface DailyReelQualityReport {
  version: string;
  passed: boolean;
  validatedAt: string;
  findings: DailyReelQualityFinding[];
}

export interface DailyReelQualityContext {
  recentMovieIds?: readonly string[];
  recentThemeKeys?: readonly string[];
  now?: () => Date;
}

export function evaluateDailyReelCandidate(
  candidate: DailyReelCandidate,
  context: DailyReelQualityContext = {},
): DailyReelQualityReport {
  const findings: DailyReelQualityFinding[] = [];
  const parsed = DailyReelPrivateSchema.safeParse(candidate.privateReel);
  if (!parsed.success) {
    findings.push({
      code: "contract.invalid",
      severity: "error",
      message: "Candidate does not satisfy the private Daily Reel contract",
    });
    return report(findings, context.now);
  }

  if (!candidate.safety.isSafe || candidate.safety.categories.length > 0) {
    findings.push({
      code: "safety.blocked",
      severity: "error",
      message: "Candidate failed the generated-content safety gate",
    });
  }

  const reel = parsed.data.reel;
  const answers = parsed.data.answers;
  const baseline = reel.localized.en;
  const baselineActIDs = baseline.acts.map((act) => act.id);
  const baselineConnectFilms = baseline.acts[1].films.map((film) => film.id);
  const baselineConnectChoices = baseline.acts[1].choices.map((choice) => choice.id);
  const baselineArrangeFilms = baseline.acts[2].films.map((film) => film.id);

  for (const locale of DAILY_REEL_LOCALES) {
    const content = reel.localized[locale];
    requireEqualSequence(
      content.acts.map((act) => act.id),
      baselineActIDs,
      findings,
      "locale.act_ids_mismatch",
      "Localized acts must preserve the English act IDs",
      locale,
    );
    requireEqualSequence(
      content.acts[1].films.map((film) => film.id),
      baselineConnectFilms,
      findings,
      "locale.connect_films_mismatch",
      "Localized Connect films must preserve the same IDs and order",
      locale,
      "connect",
    );
    requireEqualSequence(
      content.acts[1].choices.map((choice) => choice.id),
      baselineConnectChoices,
      findings,
      "locale.connect_choices_mismatch",
      "Localized Connect choices must preserve the same IDs and order",
      locale,
      "connect",
    );
    requireEqualSequence(
      content.acts[2].films.map((film) => film.id),
      baselineArrangeFilms,
      findings,
      "locale.arrange_films_mismatch",
      "Localized Arrange films must preserve the same IDs and display order",
      locale,
      "arrange",
    );

    const expectedTitleLength = countLettersAndNumbers(answers[locale].decode.revealTitle);
    if (answers[locale].decode.titleLength !== expectedTitleLength) {
      findings.push({
        code: "decode.title_length_invalid",
        severity: "error",
        message: "Decode title length must match the localized reveal title",
        locale,
        actRole: "decode",
      });
    }

    const publicText = collectPublicText(content);
    const leakedAnswer = answers[locale].decode.acceptedAnswers.some((answer) => {
      const normalizedAnswer = normalizeText(answer);
      return normalizedAnswer.length >= 4 && publicText.includes(normalizedAnswer);
    });
    if (leakedAnswer) {
      findings.push({
        code: "decode.answer_leak",
        severity: "error",
        message: "A Decode accepted answer appears in the public projection",
        locale,
        actRole: "decode",
      });
    }

    const threadReveal = answers[locale].threadReveal;
    if (!threadReveal) {
      findings.push({
        code: "thread.reveal_missing",
        severity: "error",
        message: "Every locale needs a completion-only thread reveal",
        locale,
      });
    } else {
      const explanation = normalizeText(threadReveal.explanation);
      const bridgesDecode = explanation.includes(normalizeText(answers[locale].decode.revealTitle));
      const bridgesConnect = content.acts[1].films.some((film) =>
        explanation.includes(normalizeText(film.title)),
      );
      const bridgesArrange = content.acts[2].films.some((film) =>
        explanation.includes(normalizeText(film.title)),
      );
      if (normalizeText(threadReveal.title) === normalizeText(content.theme)) {
        findings.push({
          code: "thread.reveal_generic",
          severity: "error",
          message: "The completion thread must be more specific than the public theme",
          locale,
        });
      }
      if (!bridgesDecode || !bridgesConnect || !bridgesArrange) {
        findings.push({
          code: "thread.reveal_disconnected",
          severity: "error",
          message: "The completion thread must explicitly bridge material from all three acts",
          locale,
        });
      }
    }
  }

  if (candidate.difficulty.decode === "easy" && candidate.difficulty.connect === "easy") {
    findings.push({
      code: "difficulty.opening_too_easy",
      severity: "error",
      message: "Decode and Connect cannot both be rated easy",
    });
  }

  const facts = new Map(candidate.movieFacts.map((fact) => [fact.movieId, fact]));
  const referencedMovieIDs = new Set([...baselineConnectFilms, ...baselineArrangeFilms]);
  for (const movieId of referencedMovieIDs) {
    if (!facts.has(movieId)) {
      findings.push({
        code: "facts.movie_missing",
        severity: "error",
        message: `No TMDb fact snapshot exists for ${movieId}`,
      });
    }
  }

  validateConnection(candidate.connection, baselineConnectFilms, facts, findings);
  validateArrangeOrder(baselineArrangeFilms, facts, answers, findings);
  validateArrangeDifficulty(candidate.difficulty.arrange, baselineArrangeFilms, facts, findings);

  const recentMovieIDs = new Set(context.recentMovieIds ?? []);
  for (const movieId of referencedMovieIDs) {
    if (recentMovieIDs.has(movieId)) {
      findings.push({
        code: "cooldown.movie_reused",
        severity: "error",
        message: `Movie ${movieId} is still inside the recent-content cooldown`,
      });
    }
  }

  const normalizedTheme = normalizeText(reel.localized.en.theme);
  const recentThemes = new Set((context.recentThemeKeys ?? []).map(normalizeText));
  if (recentThemes.has(normalizedTheme)) {
    findings.push({
      code: "cooldown.theme_reused",
      severity: "error",
      message: "The English theme is still inside the recent-content cooldown",
    });
  }

  if (candidate.connection.kind === "theme") {
    findings.push({
      code: "connection.theme_editorial_review",
      severity: "warning",
      message: "Subjective theme connections require explicit evidence review by the editor",
      actRole: "connect",
    });
  }

  return report(findings, context.now);
}

function validateConnection(
  connection: DailyReelConnection,
  movieIDs: readonly string[],
  facts: ReadonlyMap<string, DailyReelMovieFact>,
  findings: DailyReelQualityFinding[],
): void {
  for (const movieId of movieIDs) {
    if (!connection.evidenceByMovieId[movieId]) {
      findings.push({
        code: "connection.evidence_missing",
        severity: "error",
        message: `Connect evidence is missing for ${movieId}`,
        actRole: "connect",
      });
    }
  }

  if (connection.kind === "theme") {
    return;
  }

  for (const movieId of movieIDs) {
    const fact = facts.get(movieId);
    if (!fact) continue;

    let matches = false;
    switch (connection.kind) {
    case "actor":
      matches = fact.actorIds.includes(connection.key);
      break;
    case "director":
      matches = fact.directorIds.includes(connection.key);
      break;
    case "franchise":
      matches = fact.franchiseId === connection.key;
      break;
    case "genre":
      matches = fact.genreIds.map(String).includes(connection.key);
      break;
    }

    if (!matches) {
      findings.push({
        code: "connection.fact_mismatch",
        severity: "error",
        message: `TMDb facts do not support the ${connection.kind} link for ${movieId}`,
        actRole: "connect",
      });
    }
  }
}

function validateArrangeOrder(
  displayedMovieIDs: readonly string[],
  facts: ReadonlyMap<string, DailyReelMovieFact>,
  answers: ReturnType<typeof DailyReelPrivateSchema.parse>["answers"],
  findings: DailyReelQualityFinding[],
): void {
  if (displayedMovieIDs.some((movieId) => !facts.has(movieId))) {
    return;
  }

  const expectedOrder = [...displayedMovieIDs].sort((left, right) => {
    const leftDate = facts.get(left)?.releaseDate ?? "";
    const rightDate = facts.get(right)?.releaseDate ?? "";
    return leftDate.localeCompare(rightDate) || left.localeCompare(right);
  });

  for (const locale of DAILY_REEL_LOCALES) {
    if (!sameSequence(answers[locale].arrange.correctOrder, expectedOrder)) {
      findings.push({
        code: "arrange.release_order_invalid",
        severity: "error",
        message: "Arrange answer does not match TMDb release dates",
        locale,
        actRole: "arrange",
      });
    }
  }
}

function validateArrangeDifficulty(
  declaredDifficulty: DailyReelDifficulty["arrange"],
  displayedMovieIDs: readonly string[],
  facts: ReadonlyMap<string, DailyReelMovieFact>,
  findings: DailyReelQualityFinding[],
): void {
  const releaseTimes = displayedMovieIDs
    .map((movieId) => Date.parse(facts.get(movieId)?.releaseDate ?? ""))
    .filter(Number.isFinite)
    .sort((left, right) => left - right);
  if (releaseTimes.length !== displayedMovieIDs.length) return;

  const spanDays = (releaseTimes.at(-1)! - releaseTimes[0]) / 86_400_000;
  const inferredDifficulty: DailyReelDifficulty["arrange"] = spanDays <= 366
    ? "hard"
    : spanDays <= 3_653
      ? "medium"
      : "easy";

  if (declaredDifficulty !== inferredDifficulty) {
    findings.push({
      code: "difficulty.arrange_mislabeled",
      severity: "error",
      message: `Arrange is labeled ${declaredDifficulty}, but its ${Math.round(spanDays)}-day release span is ${inferredDifficulty}`,
      actRole: "arrange",
    });
  }
  if (inferredDifficulty === "easy") {
    findings.push({
      code: "difficulty.arrange_payoff_too_easy",
      severity: "error",
      message: "Arrange needs films released within ten years so the final act delivers a meaningful challenge",
      actRole: "arrange",
    });
  }
}

function collectPublicText(content: ReturnType<typeof DailyReelPrivateSchema.parse>["reel"]["localized"]["en"]): string {
  const connect = content.acts[1];
  const arrange = content.acts[2];
  return normalizeText([
    content.theme,
    content.shareText,
    ...content.acts.map((act) => act.prompt),
    ...content.acts.flatMap((act) => act.assistOptions.map((option) => option.label)),
    ...connect.films.map((film) => film.title),
    ...connect.choices.map((choice) => choice.label),
    ...arrange.films.map((film) => film.title),
  ].join(" "));
}

function countLettersAndNumbers(value: string): number {
  return Array.from(value.normalize("NFKC")).filter((character) => /[\p{L}\p{N}]/u.test(character)).length;
}

function normalizeText(value: string): string {
  return value
    .normalize("NFKD")
    .replace(/\p{M}/gu, "")
    .toLocaleLowerCase()
    .replace(/[^\p{L}\p{N}]+/gu, " ")
    .trim();
}

function sameSequence(left: readonly string[], right: readonly string[]): boolean {
  return left.length === right.length && left.every((value, index) => value === right[index]);
}

function requireEqualSequence(
  actual: readonly string[],
  expected: readonly string[],
  findings: DailyReelQualityFinding[],
  code: string,
  message: string,
  locale: DailyReelLocale,
  actRole?: "decode" | "connect" | "arrange",
): void {
  if (!sameSequence(actual, expected)) {
    findings.push({ code, severity: "error", message, locale, actRole });
  }
}

function report(
  findings: DailyReelQualityFinding[],
  now: (() => Date) | undefined,
): DailyReelQualityReport {
  return {
    version: DAILY_REEL_QUALITY_VERSION,
    passed: findings.every((finding) => finding.severity !== "error"),
    validatedAt: (now ?? (() => new Date()))().toISOString(),
    findings,
  };
}
