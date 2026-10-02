import { describe, expect, it, vi } from "vitest";

import { runDailyPuzzlePipeline } from "../pipeline.js";
import type { DailyPuzzleDocument } from "../puzzleSchema.js";

const samplePuzzle: DailyPuzzleDocument = {
  date: "2026-02-15",
  puzzle_id: "2026-02-15",
  media_type: "movie",
  tmdb_id: 597,
  title: "Titanic",
  emoji_clue: "🚢🧊❤️",
  hint_1: "Released in 1997",
  hint_2: "Directed by James Cameron",
  accepted_answers: ["titanic"],
  source: "ai+tmdb",
  practice_eligible: true,
  generated_at: "2026-02-15T05:00:00.000Z"
};

function createLogger() {
  return {
    info: vi.fn(),
    error: vi.fn()
  };
}

describe("runDailyPuzzlePipeline", () => {
  it("returns generated false and pushSent false when puzzle already exists", async () => {
    const logger = createLogger();
    const generatePuzzle = vi.fn();
    const persistPuzzle = vi.fn();
    const sendPush = vi.fn();

    const result = await runDailyPuzzlePipeline({
      targetDate: new Date("2026-02-15T05:00:00.000Z"),
      loadAdminConfig: async () => ({ enabled: true, pushEnabled: true }),
      loadExistingPuzzle: async () => samplePuzzle,
      generatePuzzle,
      persistPuzzle,
      sendPush,
      formatPushBody: () => "🚢 + 🧊 + ❤️ = ______",
      logger
    });

    expect(result).toEqual({ generated: false, pushSent: false });
    expect(generatePuzzle).not.toHaveBeenCalled();
    expect(persistPuzzle).not.toHaveBeenCalled();
    expect(sendPush).not.toHaveBeenCalled();
  });

  it("returns generated false and pushSent true when existing puzzle push is enabled", async () => {
    const logger = createLogger();
    const generatePuzzle = vi.fn();
    const persistPuzzle = vi.fn();
    const sendPush = vi.fn();
    const syncLatestPuzzleFromExisting = vi.fn();
    const existingPuzzle = {
      ...samplePuzzle,
      source: "manual-seed"
    };

    const result = await runDailyPuzzlePipeline({
      targetDate: new Date("2026-02-15T05:00:00.000Z"),
      loadAdminConfig: async () => ({ enabled: true, pushEnabled: true }),
      loadExistingPuzzle: async () => existingPuzzle,
      sendPushWhenPuzzleExists: true,
      syncLatestPuzzleFromExisting,
      generatePuzzle,
      persistPuzzle,
      sendPush,
      formatPushBody: () => "🚢 + 🧊 + ❤️ = ______",
      logger
    });

    expect(result).toEqual({ generated: false, pushSent: true });
    expect(generatePuzzle).not.toHaveBeenCalled();
    expect(persistPuzzle).not.toHaveBeenCalled();
    expect(syncLatestPuzzleFromExisting).toHaveBeenCalledWith(
      expect.objectContaining({
        date: "2026-02-15",
        puzzle_id: "2026-02-15",
        hint_1: "Released in 1997",
        hint_2: "Directed by James Cameron"
      })
    );
    expect(sendPush).toHaveBeenCalledWith(
      expect.objectContaining({
        date: "2026-02-15",
        puzzle_id: "2026-02-15",
        emoji_clue: "🚢🧊❤️"
      }),
      "🚢 + 🧊 + ❤️ = ______"
    );
  });

  it("returns generated true and pushSent true when generation and push are enabled", async () => {
    const logger = createLogger();
    const persistPuzzle = vi.fn();
    const sendPush = vi.fn();

    const result = await runDailyPuzzlePipeline({
      targetDate: new Date("2026-02-15T05:00:00.000Z"),
      loadAdminConfig: async () => ({ enabled: true, pushEnabled: true }),
      loadExistingPuzzle: async () => null,
      generatePuzzle: async () => samplePuzzle,
      persistPuzzle,
      sendPush,
      formatPushBody: () => "🚢 + 🧊 + ❤️ = ______",
      logger
    });

    expect(result).toEqual({ generated: true, pushSent: true });
    expect(persistPuzzle).toHaveBeenCalledOnce();
    expect(sendPush).toHaveBeenCalledWith(samplePuzzle, "🚢 + 🧊 + ❤️ = ______");
  });

  it("returns generated true and pushSent false when push is disabled", async () => {
    const logger = createLogger();
    const persistPuzzle = vi.fn();
    const sendPush = vi.fn();

    const result = await runDailyPuzzlePipeline({
      targetDate: new Date("2026-02-15T05:00:00.000Z"),
      loadAdminConfig: async () => ({ enabled: true, pushEnabled: false }),
      loadExistingPuzzle: async () => null,
      generatePuzzle: async () => samplePuzzle,
      persistPuzzle,
      sendPush,
      formatPushBody: () => "🚢 + 🧊 + ❤️ = ______",
      logger
    });

    expect(result).toEqual({ generated: true, pushSent: false });
    expect(persistPuzzle).toHaveBeenCalledOnce();
    expect(sendPush).not.toHaveBeenCalled();
  });
});
