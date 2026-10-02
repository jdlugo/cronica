import { describe, expect, it } from "vitest";

import { isPastPrimaryGenerationWindow, resolveScheduleTargetDate } from "../coverageSchedule.js";

describe("coverage schedule policy", () => {
  it("resolves target date from scheduleTime when available", () => {
    const resolved = resolveScheduleTargetDate("2026-02-16T05:17:00.000Z");
    expect(resolved.toISOString()).toBe("2026-02-16T05:17:00.000Z");
  });

  it("falls back to provided current date when scheduleTime is missing", () => {
    const fallback = new Date("2026-02-16T00:00:00.000Z");
    const resolved = resolveScheduleTargetDate(undefined, fallback);
    expect(resolved.toISOString()).toBe("2026-02-16T00:00:00.000Z");
  });

  it("falls back to provided current date when scheduleTime is invalid", () => {
    const fallback = new Date("2026-02-16T00:00:00.000Z");
    const resolved = resolveScheduleTargetDate("not-a-date", fallback);
    expect(resolved.toISOString()).toBe("2026-02-16T00:00:00.000Z");
  });

  it("returns false before the primary generation window", () => {
    expect(isPastPrimaryGenerationWindow(new Date("2026-02-16T05:04:59.000Z"))).toBe(false);
  });

  it("returns true at or after the primary generation window", () => {
    expect(isPastPrimaryGenerationWindow(new Date("2026-02-16T05:05:00.000Z"))).toBe(true);
    expect(isPastPrimaryGenerationWindow(new Date("2026-02-16T23:17:00.000Z"))).toBe(true);
  });
});
