const graphemeSegmenter = new Intl.Segmenter("en", { granularity: "grapheme" });

const stopWordsByLanguage: Record<string, Set<string>> = {
  en: new Set([
    "a", "an", "and", "as", "at", "by", "for", "from", "in", "into", "of", "on", "or", "the", "to", "with"
  ]),
  es: new Set([
    "a", "al", "de", "del", "el", "en", "la", "las", "los", "o", "para", "por", "un", "una", "y"
  ]),
  fr: new Set([
    "au", "aux", "de", "des", "du", "et", "la", "le", "les", "ou", "pour", "un", "une"
  ]),
  pt: new Set([
    "a", "ao", "as", "de", "do", "dos", "e", "em", "o", "os", "ou", "para", "por", "um", "uma"
  ])
};

function normalizeWordTokens(value: string): string[] {
  return value
    .toLowerCase()
    .replace(/['’]/gu, "")
    .replace(/[^\p{L}\p{N}]+/gu, " ")
    .trim()
    .split(/\s+/u)
    .filter((token) => token.length > 0);
}

function normalizeCanonicalTitle(value: string): string {
  return value.trim().toLowerCase();
}

export function countGraphemes(value: string): number {
  return Array.from(graphemeSegmenter.segment(value), (segment) => segment.segment).filter(
    (segment) => segment.trim().length > 0
  ).length;
}

export function normalizeTitleTokens(title: string, locale = "en"): string[] {
  const language = locale.toLowerCase().split(/[-_]/u)[0];
  const stopWords = stopWordsByLanguage[language] ?? stopWordsByLanguage.en;
  return Array.from(
    new Set(
      normalizeWordTokens(title).filter((token) => !stopWords.has(token))
    )
  );
}

export function assertPuzzleQuality(input: {
  title: string;
  emojiClue: string;
  hint1: string;
  hint2: string;
  acceptedAnswers: string[];
  locale?: string;
}): void {
  const emojiCount = countGraphemes(input.emojiClue);
  if (emojiCount < 3 || emojiCount > 5) {
    throw new Error(`Emoji clue must contain 3 to 5 graphemes; received ${emojiCount}`);
  }

  const titleTokens = normalizeTitleTokens(input.title, input.locale);
  const hint1Tokens = new Set(normalizeWordTokens(input.hint1));
  const hint2Tokens = new Set(normalizeWordTokens(input.hint2));

  for (const token of titleTokens) {
    if (hint1Tokens.has(token)) {
      throw new Error(`Hint contains title token "${token}" in hint1`);
    }

    if (hint2Tokens.has(token)) {
      throw new Error(`Hint contains title token "${token}" in hint2`);
    }
  }

  const canonicalTitle = normalizeCanonicalTitle(input.title);
  const normalizedAnswers = new Set(
    input.acceptedAnswers.map((answer) => normalizeCanonicalTitle(answer))
  );
  if (!normalizedAnswers.has(canonicalTitle)) {
    throw new Error(`Accepted answers must include canonical title "${canonicalTitle}"`);
  }
}
