function dayStamp(date: Date): string {
  return date.toISOString().slice(0, 10);
}

export function buildLookbackDateStamps(targetDate: Date, lookbackDays = 30): string[] {
  const dates: string[] = [];

  for (let dayOffset = 1; dayOffset <= lookbackDays; dayOffset += 1) {
    const date = new Date(targetDate);
    date.setUTCDate(date.getUTCDate() - dayOffset);
    dates.push(dayStamp(date));
  }

  return dates;
}

interface PuzzleDocumentLike {
  tmdb_id?: unknown;
}

export function extractRecentTmdbIDs(documents: PuzzleDocumentLike[]): number[] {
  const ids = new Set<number>();

  for (const document of documents) {
    const tmdbID = document.tmdb_id;
    if (typeof tmdbID === "number" && Number.isFinite(tmdbID)) {
      ids.add(tmdbID);
    }
  }

  return Array.from(ids);
}

interface WarningLogger {
  warn: (message: string, metadata?: unknown) => void;
}

interface FetchCandidateWithExclusionFallbackInput<TCandidate> {
  excludedTmdbIDs: number[];
  fetchWithExclusions: (excludedTmdbIDs: number[]) => Promise<TCandidate>;
  fetchWithoutExclusions: () => Promise<TCandidate>;
  logger: WarningLogger;
}

export async function fetchCandidateWithExclusionFallback<TCandidate>(
  input: FetchCandidateWithExclusionFallbackInput<TCandidate>
): Promise<TCandidate> {
  try {
    return await input.fetchWithExclusions(input.excludedTmdbIDs);
  } catch (error) {
    const message = error instanceof Error ? error.message : "";
    if (!message.includes("No suitable TMDb candidate")) {
      throw error;
    }

    input.logger.warn("TMDb selection with exclusions failed; retrying without exclusion history.", {
      excludedCount: input.excludedTmdbIDs.length
    });

    return input.fetchWithoutExclusions();
  }
}

export function isAlreadyExistsError(error: unknown): boolean {
  if (typeof error !== "object" || error == null || !("code" in error)) {
    return false;
  }

  const code = (error as { code: unknown }).code;
  return code === 6 || code === "already-exists";
}
