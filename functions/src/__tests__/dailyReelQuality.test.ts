import { describe, expect, it } from "vitest";
import { evaluateDailyReelCandidate } from "../dailyReelQuality.js";
import { clone, makeCandidate } from "./dailyReelTestFixtures.js";

describe("evaluateDailyReelCandidate", () => {
  it("passes a five-locale fact-grounded candidate", () => {
    const report = evaluateDailyReelCandidate(makeCandidate(), {
      now: () => new Date("2026-08-28T12:00:00Z"),
    });

    expect(report.passed).toBe(true);
    expect(report.findings).toEqual([]);
  });

  it("rejects a Connect relationship unsupported by all three films", () => {
    const candidate = clone(makeCandidate());
    candidate.movieFacts[0].directorIds = ["person:someone-else"];

    const report = evaluateDailyReelCandidate(candidate);

    expect(report.passed).toBe(false);
    expect(report.findings.map((finding) => finding.code)).toContain("connection.fact_mismatch");
  });

  it("rejects an Arrange answer that contradicts release dates", () => {
    const candidate = clone(makeCandidate());
    candidate.privateReel.answers.en.arrange.correctOrder = ["tmdb:603", "tmdb:218", "tmdb:27205"];

    const report = evaluateDailyReelCandidate(candidate);

    expect(report.passed).toBe(false);
    expect(report.findings.map((finding) => finding.code)).toContain("arrange.release_order_invalid");
  });

  it("rejects leaked Decode answers", () => {
    const candidate = clone(makeCandidate());
    candidate.privateReel.reel.localized.en.acts[0].prompt = "Decode Back to the Future";

    const report = evaluateDailyReelCandidate(candidate);

    expect(report.passed).toBe(false);
    expect(report.findings.map((finding) => finding.code)).toContain("decode.answer_leak");
  });

  it("rejects recent movie and theme reuse", () => {
    const report = evaluateDailyReelCandidate(makeCandidate(), {
      recentMovieIds: ["tmdb:329"],
      recentThemeKeys: ["extraordinary journeys"],
    });

    expect(report.passed).toBe(false);
    expect(report.findings.map((finding) => finding.code)).toEqual(
      expect.arrayContaining(["cooldown.movie_reused", "cooldown.theme_reused"]),
    );
  });

  it("rejects localized film identity drift", () => {
    const candidate = clone(makeCandidate());
    candidate.privateReel.reel.localized["fr-FR"].acts[1].films[0].id = "tmdb:wrong";

    const report = evaluateDailyReelCandidate(candidate);

    expect(report.passed).toBe(false);
    expect(report.findings.map((finding) => finding.code)).toContain("locale.connect_films_mismatch");
  });

  it("rejects a reel without a localized completion thread", () => {
    const candidate = clone(makeCandidate());
    delete candidate.privateReel.answers.en.threadReveal;

    const report = evaluateDailyReelCandidate(candidate);

    expect(report.passed).toBe(false);
    expect(report.findings.map((finding) => finding.code)).toContain("thread.reveal_missing");
  });

  it("rejects an easy Decode followed by an easy Connect act", () => {
    const candidate = clone(makeCandidate());
    candidate.difficulty.decode = "easy";
    candidate.difficulty.connect = "easy";

    const report = evaluateDailyReelCandidate(candidate);

    expect(report.passed).toBe(false);
    expect(report.findings.map((finding) => finding.code)).toContain("difficulty.opening_too_easy");
  });

  it("rejects a mislabeled, decade-spanning Arrange payoff", () => {
    const candidate = clone(makeCandidate());
    candidate.difficulty.arrange = "medium";
    candidate.movieFacts.find((fact) => fact.movieId === "tmdb:218")!.releaseDate = "1984-10-26";
    candidate.movieFacts.find((fact) => fact.movieId === "tmdb:603")!.releaseDate = "1999-03-31";
    candidate.movieFacts.find((fact) => fact.movieId === "tmdb:27205")!.releaseDate = "2010-07-15";

    const report = evaluateDailyReelCandidate(candidate);

    expect(report.passed).toBe(false);
    expect(report.findings.map((finding) => finding.code)).toEqual(
      expect.arrayContaining([
        "difficulty.arrange_mislabeled",
        "difficulty.arrange_payoff_too_easy",
      ]),
    );
  });
});
