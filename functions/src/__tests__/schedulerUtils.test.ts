import { describe, expect, it, vi } from "vitest";

import {
  buildLookbackDateStamps,
  extractRecentTmdbIDs,
  fetchCandidateWithExclusionFallback,
  isAlreadyExistsError
} from "../schedulerUtils.js";

describe("buildLookbackDateStamps", () => {
  it("returns prior UTC dates only, newest first", () => {
    const targetDate = new Date("2026-02-16T05:00:00.000Z");

    const stamps = buildLookbackDateStamps(targetDate, 3);

    expect(stamps).toEqual(["2026-02-15", "2026-02-14", "2026-02-13"]);
  });
});

describe("extractRecentTmdbIDs", () => {
  it("deduplicates numeric tmdb ids and ignores invalid values", () => {
    const ids = extractRecentTmdbIDs([
      { tmdb_id: 597 },
      { tmdb_id: 27205 },
      { tmdb_id: 597 },
      { tmdb_id: "597" },
      { tmdb_id: Number.NaN },
      {}
    ]);

    expect(ids).toEqual([597, 27205]);
  });
});

describe("fetchCandidateWithExclusionFallback", () => {
  it("retries without exclusions when only exclusion filtering causes no-candidate error", async () => {
    const logger = { warn: vi.fn() };
    const fetchWithExclusions = vi.fn(async () => {
      throw new Error("No suitable TMDb candidate found for daily puzzle generation");
    });
    const fetchWithoutExclusions = vi.fn(async () => ({ id: 597, title: "Titanic" }));

    const candidate = await fetchCandidateWithExclusionFallback({
      excludedTmdbIDs: [597, 27205],
      fetchWithExclusions,
      fetchWithoutExclusions,
      logger
    });

    expect(fetchWithExclusions).toHaveBeenCalledWith([597, 27205]);
    expect(fetchWithoutExclusions).toHaveBeenCalledOnce();
    expect(logger.warn).toHaveBeenCalledOnce();
    expect(candidate).toEqual({ id: 597, title: "Titanic" });
  });

  it("rethrows non-filtering errors without fallback retry", async () => {
    const logger = { warn: vi.fn() };
    const fetchWithExclusions = vi.fn(async () => {
      throw new Error("TMDb discover request failed with status 500");
    });
    const fetchWithoutExclusions = vi.fn(async () => ({ id: 597, title: "Titanic" }));

    await expect(
      fetchCandidateWithExclusionFallback({
        excludedTmdbIDs: [597],
        fetchWithExclusions,
        fetchWithoutExclusions,
        logger
      })
    ).rejects.toThrow("TMDb discover request failed with status 500");

    expect(fetchWithoutExclusions).not.toHaveBeenCalled();
    expect(logger.warn).not.toHaveBeenCalled();
  });
});

describe("isAlreadyExistsError", () => {
  it("returns true for numeric firestore already-exists code", () => {
    expect(isAlreadyExistsError({ code: 6 })).toBe(true);
  });

  it("returns true for string firestore already-exists code", () => {
    expect(isAlreadyExistsError({ code: "already-exists" })).toBe(true);
  });

  it("returns false for non-matching errors", () => {
    expect(isAlreadyExistsError(new Error("boom"))).toBe(false);
    expect(isAlreadyExistsError({ code: 5 })).toBe(false);
    expect(isAlreadyExistsError({ code: "internal" })).toBe(false);
    expect(isAlreadyExistsError(null)).toBe(false);
  });
});
