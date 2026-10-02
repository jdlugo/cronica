export interface TmdbMovieResult {
  id: number;
  title: string;
  overview: string;
  popularity: number;
  vote_count: number;
  vote_average: number;
  release_date: string;
  adult: boolean;
}

export const targetPuzzleLocales = ["fr-FR", "es-MX", "pt-BR"] as const;
export type TmdbPuzzleLocale = (typeof targetPuzzleLocales)[number];

export interface TmdbLocalizedMovieResult {
  locale: TmdbPuzzleLocale;
  title: string;
  overview: string;
  alternativeTitles: string[];
}

interface TmdbDiscoverResponse {
  results: TmdbMovieResult[];
}

interface FetchTmdbCandidateOptions {
  apiKey: string;
  fetchFn?: typeof fetch;
  targetDate?: Date;
  excludeTmdbIDs?: number[];
}

interface FetchTmdbLocalizationsOptions {
  apiKey: string;
  movie: TmdbMovieResult;
  fetchFn?: typeof fetch;
}

interface TmdbMovieDetailsResponse {
  title?: string;
  overview?: string;
}

interface TmdbAlternativeTitlesResponse {
  titles?: Array<{
    iso_3166_1?: string;
    title?: string;
  }>;
}

const localeRegions: Record<TmdbPuzzleLocale, string> = {
  "fr-FR": "FR",
  "es-MX": "MX",
  "pt-BR": "BR"
};

const STRICT_MIN_VOTE_COUNT = 5_000;
const RELAXED_MIN_VOTE_COUNT = 1_500;
const STRICT_MIN_POPULARITY = 15;
const RELAXED_MIN_POPULARITY = 8;

function isWithinTopicalWindow(releaseDate: string, targetDate: Date, yearsBack: number): boolean {
  const releaseYear = Number(releaseDate.slice(0, 4));
  if (!Number.isFinite(releaseYear)) {
    return false;
  }

  return releaseYear >= targetDate.getUTCFullYear() - yearsBack;
}

function scoreCandidate(movie: TmdbMovieResult): number {
  const popularityScore = Math.min(movie.popularity, 100) * 0.5;
  const voteCountScore = Math.log10(Math.max(movie.vote_count, 1)) * 80;
  const voteAverageScore = movie.vote_average * 3;
  return popularityScore + voteCountScore + voteAverageScore;
}

function movieHasRequiredFields(movie: TmdbMovieResult): boolean {
  return (
    !movie.adult &&
    movie.title.trim().length > 0 &&
    movie.overview.trim().length > 0 &&
    movie.release_date.trim().length >= 4
  );
}

export function pickCandidateFromTmdbResults(
  results: TmdbMovieResult[],
  targetDate: Date,
  excludedTmdbIDs: Set<number> = new Set()
): TmdbMovieResult {
  const candidatePool = results.filter(
    (movie) => movieHasRequiredFields(movie) && !excludedTmdbIDs.has(movie.id)
  );

  const strictMatches = candidatePool.filter(
    (movie) =>
      movie.vote_count >= STRICT_MIN_VOTE_COUNT &&
      movie.popularity >= STRICT_MIN_POPULARITY &&
      movie.vote_average >= 6.0 &&
      isWithinTopicalWindow(movie.release_date, targetDate, 40)
  );

  const relaxedMatches = candidatePool.filter(
    (movie) =>
      movie.vote_count >= RELAXED_MIN_VOTE_COUNT &&
      movie.popularity >= RELAXED_MIN_POPULARITY &&
      movie.vote_average >= 5.8 &&
      isWithinTopicalWindow(movie.release_date, targetDate, 60)
  );

  const matches = strictMatches.length > 0 ? strictMatches : relaxedMatches;
  if (matches.length === 0) {
    throw new Error("No suitable TMDb candidate found for daily puzzle generation");
  }

  return [...matches].sort((a, b) => scoreCandidate(b) - scoreCandidate(a))[0];
}

function dateString(date: Date): string {
  return date.toISOString().slice(0, 10);
}

export async function fetchTmdbCandidate(options: FetchTmdbCandidateOptions): Promise<TmdbMovieResult> {
  const fetchFn = options.fetchFn ?? fetch;
  const targetDate = options.targetDate ?? new Date();
  const excludedTmdbIDs = new Set(options.excludeTmdbIDs ?? []);

  const baseUrl = "https://api.themoviedb.org/3/discover/movie";
  const allResults: TmdbMovieResult[] = [];

  for (const page of [1, 2]) {
    const url = new URL(baseUrl);
    url.searchParams.set("api_key", options.apiKey);
    url.searchParams.set("language", "en-US");
    url.searchParams.set("include_adult", "false");
    url.searchParams.set("include_video", "false");
    url.searchParams.set("sort_by", "popularity.desc");
    url.searchParams.set("vote_count.gte", "350");
    url.searchParams.set("vote_average.gte", "5.8");
    url.searchParams.set("primary_release_date.lte", dateString(targetDate));
    url.searchParams.set("page", String(page));

    const response = await fetchFn(url.toString());
    if (!response.ok) {
      throw new Error(`TMDb discover request failed with status ${response.status}`);
    }

    const payload = (await response.json()) as TmdbDiscoverResponse;
    allResults.push(...(payload.results ?? []));
  }

  return pickCandidateFromTmdbResults(allResults, targetDate, excludedTmdbIDs);
}

export async function fetchTmdbLocalizations(
  options: FetchTmdbLocalizationsOptions
): Promise<TmdbLocalizedMovieResult[]> {
  const fetchFn = options.fetchFn ?? fetch;
  const alternativeTitlesUrl = new URL(
    `https://api.themoviedb.org/3/movie/${options.movie.id}/alternative_titles`
  );
  alternativeTitlesUrl.searchParams.set("api_key", options.apiKey);

  const alternativeTitlesResponse = await fetchFn(alternativeTitlesUrl.toString());
  if (!alternativeTitlesResponse.ok) {
    throw new Error(
      `TMDb alternative titles request failed with status ${alternativeTitlesResponse.status}`
    );
  }
  const alternativeTitlesPayload = (
    await alternativeTitlesResponse.json()
  ) as TmdbAlternativeTitlesResponse;

  return Promise.all(
    targetPuzzleLocales.map(async (locale) => {
      const detailsUrl = new URL(`https://api.themoviedb.org/3/movie/${options.movie.id}`);
      detailsUrl.searchParams.set("api_key", options.apiKey);
      detailsUrl.searchParams.set("language", locale);

      const response = await fetchFn(detailsUrl.toString());
      if (!response.ok) {
        throw new Error(`TMDb ${locale} details request failed with status ${response.status}`);
      }

      const payload = (await response.json()) as TmdbMovieDetailsResponse;
      const title = payload.title?.trim() || options.movie.title;
      const overview = payload.overview?.trim() || options.movie.overview;
      const alternativeTitles = Array.from(
        new Set(
          (alternativeTitlesPayload.titles ?? [])
            .filter((item) => item.iso_3166_1 === localeRegions[locale])
            .map((item) => item.title?.trim() ?? "")
            .filter((item) => item.length > 0 && item !== title)
        )
      );

      return { locale, title, overview, alternativeTitles };
    })
  );
}
