import { describe, expect, it } from "vitest";

import {
  fetchTmdbLocalizations,
  pickCandidateFromTmdbResults,
  type TmdbMovieResult
} from "../tmdb.js";

describe("tmdb candidate selection", () => {
  it("prefers common, popular, non-obscure movies", () => {
    const results: TmdbMovieResult[] = [
      {
        id: 1,
        title: "Festival Indie Cut",
        overview: "A very niche festival title.",
        popularity: 99,
        vote_count: 11,
        vote_average: 7.2,
        release_date: "2025-11-01",
        adult: false
      },
      {
        id: 597,
        title: "Titanic",
        overview: "A seventeen-year-old aristocrat falls in love.",
        popularity: 68,
        vote_count: 25000,
        vote_average: 7.9,
        release_date: "1997-11-18",
        adult: false
      },
      {
        id: 2,
        title: "Tiny Documentary",
        overview: "Documentary with low engagement.",
        popularity: 12,
        vote_count: 120,
        vote_average: 6.5,
        release_date: "2024-08-08",
        adult: false
      }
    ];

    const candidate = pickCandidateFromTmdbResults(results, new Date("2026-02-15T00:00:00Z"));
    expect(candidate.id).toBe(597);
    expect(candidate.title).toBe("Titanic");
  });

  it("prefers an iconic movie over a temporary popularity spike", () => {
    const results: TmdbMovieResult[] = [
      {
        id: 100,
        title: "Trending This Week",
        overview: "A currently promoted streaming release.",
        popularity: 220,
        vote_count: 2_000,
        vote_average: 7.1,
        release_date: "2026-01-01",
        adult: false
      },
      {
        id: 597,
        title: "Titanic",
        overview: "A famous ocean liner meets an iceberg.",
        popularity: 68,
        vote_count: 25_000,
        vote_average: 7.9,
        release_date: "1997-11-18",
        adult: false
      }
    ];

    const candidate = pickCandidateFromTmdbResults(results, new Date("2026-02-15T00:00:00Z"));
    expect(candidate.title).toBe("Titanic");
  });

  it("throws when all titles are too obscure", () => {
    const results: TmdbMovieResult[] = [
      {
        id: 10,
        title: "Unknown 1",
        overview: "Some overview",
        popularity: 8,
        vote_count: 40,
        vote_average: 6.0,
        release_date: "2025-01-01",
        adult: false
      }
    ];

    expect(() => pickCandidateFromTmdbResults(results, new Date("2026-02-15T00:00:00Z"))).toThrow(
      /No suitable TMDb candidate/
    );
  });

  it("skips recently used tmdb ids when selecting a candidate", () => {
    const results: TmdbMovieResult[] = [
      {
        id: 597,
        title: "Titanic",
        overview: "A seventeen-year-old aristocrat falls in love.",
        popularity: 68,
        vote_count: 25000,
        vote_average: 7.9,
        release_date: "1997-11-18",
        adult: false
      },
      {
        id: 27205,
        title: "Inception",
        overview: "A thief enters dreams to steal secrets.",
        popularity: 62,
        vote_count: 35000,
        vote_average: 8.3,
        release_date: "2010-07-15",
        adult: false
      }
    ];

    const candidate = pickCandidateFromTmdbResults(
      results,
      new Date("2026-02-15T00:00:00Z"),
      new Set([27205])
    );
    expect(candidate.id).toBe(597);
  });

  it("throws when every eligible title is excluded by recent history", () => {
    const results: TmdbMovieResult[] = [
      {
        id: 597,
        title: "Titanic",
        overview: "A seventeen-year-old aristocrat falls in love.",
        popularity: 68,
        vote_count: 25000,
        vote_average: 7.9,
        release_date: "1997-11-18",
        adult: false
      }
    ];

    expect(() =>
      pickCandidateFromTmdbResults(
        results,
        new Date("2026-02-15T00:00:00Z"),
        new Set([597])
      )
    ).toThrow(/No suitable TMDb candidate/);
  });

  it("fetches target-locale titles, overviews, and regional aliases", async () => {
    const movie: TmdbMovieResult = {
      id: 920,
      title: "Cars",
      overview: "A race car learns about friendship.",
      popularity: 60,
      vote_count: 15000,
      vote_average: 7.0,
      release_date: "2006-06-08",
      adult: false
    };
    const fetchFn = async (input: string | URL | Request) => {
      const url = new URL(String(input));
      if (url.pathname.endsWith("/alternative_titles")) {
        return new Response(JSON.stringify({
          titles: [
            { iso_3166_1: "FR", title: "Cars : Quatre Roues" },
            { iso_3166_1: "BR", title: "Carros" }
          ]
        }), { status: 200 });
      }
      const language = url.searchParams.get("language");
      const localized = {
        "fr-FR": { title: "Cars : Quatre Roues", overview: "Une voiture de course découvre l'amitié." },
        "es-MX": { title: "Cars", overview: "Un auto de carreras descubre la amistad." },
        "pt-BR": { title: "Carros", overview: "Um carro de corrida descobre a amizade." }
      }[language ?? ""];
      return new Response(JSON.stringify(localized), { status: localized ? 200 : 404 });
    };

    const results = await fetchTmdbLocalizations({
      apiKey: "test-key",
      movie,
      fetchFn: fetchFn as typeof fetch
    });

    expect(results.map((item) => item.locale)).toEqual(["fr-FR", "es-MX", "pt-BR"]);
    expect(results[0].title).toBe("Cars : Quatre Roues");
    expect(results[2].alternativeTitles).toEqual([]);
  });
});
