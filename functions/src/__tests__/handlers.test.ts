import { describe, expect, it, vi } from "vitest";

import {
  handleGetLatestDailyPuzzle,
  handleGetRandomDailyPuzzle,
  handleSendDailyPuzzleTestPush,
  handleUpdateDailyPuzzleAdminConfig,
  runGenerateDailyPuzzleTask
} from "../handlers.js";
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

function createResponseRecorder() {
  const payload: {
    statusCode?: number;
    body?: unknown;
  } = {};

  const response = {
    status: vi.fn().mockImplementation((code: number) => {
      payload.statusCode = code;
      return response;
    }),
    json: vi.fn().mockImplementation((body: unknown) => {
      payload.body = body;
      return response;
    })
  };

  return { response, payload };
}

describe("runGenerateDailyPuzzleTask", () => {
  it("skips generation when admin disables daily puzzle", async () => {
    const logger = createLogger();
    const generatePuzzle = vi.fn();
    const persistPuzzle = vi.fn();
    const sendPush = vi.fn();

    const result = await runGenerateDailyPuzzleTask({
      targetDate: new Date("2026-02-15T05:00:00.000Z"),
      loadAdminConfig: async () => ({ enabled: false, pushEnabled: true }),
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

  it("stores puzzle but does not send push when push is disabled", async () => {
    const logger = createLogger();
    const persistPuzzle = vi.fn();
    const sendPush = vi.fn();

    const result = await runGenerateDailyPuzzleTask({
      targetDate: new Date("2026-02-15T05:00:00.000Z"),
      loadAdminConfig: async () => ({ enabled: true, pushEnabled: false }),
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

  it("stores puzzle and sends push when enabled", async () => {
    const logger = createLogger();
    const persistPuzzle = vi.fn();
    const sendPush = vi.fn();

    const result = await runGenerateDailyPuzzleTask({
      targetDate: new Date("2026-02-15T05:00:00.000Z"),
      loadAdminConfig: async () => ({ enabled: true, pushEnabled: true }),
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

  it("logs push errors but keeps generation successful", async () => {
    const logger = createLogger();
    const persistPuzzle = vi.fn();

    const result = await runGenerateDailyPuzzleTask({
      targetDate: new Date("2026-02-15T05:00:00.000Z"),
      loadAdminConfig: async () => ({ enabled: true, pushEnabled: true }),
      generatePuzzle: async () => samplePuzzle,
      persistPuzzle,
      sendPush: async () => {
        throw new Error("push failed");
      },
      formatPushBody: () => "🚢 + 🧊 + ❤️ = ______",
      logger
    });

    expect(result).toEqual({ generated: true, pushSent: false });
    expect(persistPuzzle).toHaveBeenCalledOnce();
    expect(logger.error).toHaveBeenCalled();
  });

  it("skips generation when puzzle already exists for target date", async () => {
    const logger = createLogger();
    const generatePuzzle = vi.fn();
    const persistPuzzle = vi.fn();
    const sendPush = vi.fn();

    const result = await runGenerateDailyPuzzleTask({
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
    expect(logger.info).toHaveBeenCalledWith(
      "Daily puzzle already exists for target date. Skipping generation."
    );
  });

  it("sends push when puzzle already exists and existing-puzzle push is enabled", async () => {
    const logger = createLogger();
    const generatePuzzle = vi.fn();
    const persistPuzzle = vi.fn();
    const sendPush = vi.fn();
    const syncLatestPuzzleFromExisting = vi.fn();
    const existingPuzzle = {
      ...samplePuzzle,
      source: "manual-seed"
    };

    const result = await runGenerateDailyPuzzleTask({
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
    expect(logger.info).toHaveBeenCalledWith(
      "Daily puzzle already exists for target date. Sending scheduled push for existing puzzle.",
      { puzzleID: "2026-02-15" }
    );
  });

  it("skips push when persistence reports puzzle already exists", async () => {
    const logger = createLogger();
    const sendPush = vi.fn();
    const persistPuzzle = vi.fn(async () => false);

    const result = await runGenerateDailyPuzzleTask({
      targetDate: new Date("2026-02-15T05:00:00.000Z"),
      loadAdminConfig: async () => ({ enabled: true, pushEnabled: true }),
      generatePuzzle: async () => samplePuzzle,
      persistPuzzle,
      sendPush,
      formatPushBody: () => "🚢 + 🧊 + ❤️ = ______",
      logger
    });

    expect(result).toEqual({ generated: false, pushSent: false });
    expect(persistPuzzle).toHaveBeenCalledOnce();
    expect(sendPush).not.toHaveBeenCalled();
    expect(logger.info).toHaveBeenCalledWith(
      "Daily puzzle persistence skipped because puzzle already exists."
    );
  });
});

describe("handleGetLatestDailyPuzzle", () => {
  it("returns 404 when latest puzzle does not exist", async () => {
    const logger = createLogger();
    const { response, payload } = createResponseRecorder();

    await handleGetLatestDailyPuzzle({
      loadLatestPuzzle: async () => null,
      response,
      logger
    });

    expect(payload.statusCode).toBe(404);
    expect(payload.body).toEqual({ error: "Latest puzzle not found" });
  });

  it("returns 200 with latest puzzle document", async () => {
    const logger = createLogger();
    const { response, payload } = createResponseRecorder();

    await handleGetLatestDailyPuzzle({
      loadLatestPuzzle: async () => samplePuzzle,
      response,
      logger
    });

    expect(payload.statusCode).toBe(200);
    expect(payload.body).toEqual(samplePuzzle);
  });

  it("returns 500 when latest puzzle read fails", async () => {
    const logger = createLogger();
    const { response, payload } = createResponseRecorder();

    await handleGetLatestDailyPuzzle({
      loadLatestPuzzle: async () => {
        throw new Error("db error");
      },
      response,
      logger
    });

    expect(payload.statusCode).toBe(500);
    expect(payload.body).toEqual({ error: "Failed to fetch latest daily puzzle" });
    expect(logger.error).toHaveBeenCalled();
  });
});

describe("handleGetRandomDailyPuzzle", () => {
  it("returns 404 when random puzzle does not exist", async () => {
    const logger = createLogger();
    const { response, payload } = createResponseRecorder();

    await handleGetRandomDailyPuzzle({
      loadRandomPuzzle: async () => null,
      response,
      logger
    });

    expect(payload.statusCode).toBe(404);
    expect(payload.body).toEqual({ error: "Random puzzle not found" });
  });

  it("returns 200 with random puzzle document", async () => {
    const logger = createLogger();
    const { response, payload } = createResponseRecorder();

    await handleGetRandomDailyPuzzle({
      loadRandomPuzzle: async () => samplePuzzle,
      response,
      logger
    });

    expect(payload.statusCode).toBe(200);
    expect(payload.body).toEqual(samplePuzzle);
  });

  it("returns 500 when random puzzle read fails", async () => {
    const logger = createLogger();
    const { response, payload } = createResponseRecorder();

    await handleGetRandomDailyPuzzle({
      loadRandomPuzzle: async () => {
        throw new Error("db error");
      },
      response,
      logger
    });

    expect(payload.statusCode).toBe(500);
    expect(payload.body).toEqual({ error: "Failed to fetch random daily puzzle" });
    expect(logger.error).toHaveBeenCalled();
  });
});

describe("handleUpdateDailyPuzzleAdminConfig", () => {
  it("returns 401 when admin key is missing or invalid", async () => {
    const logger = createLogger();
    const { response, payload } = createResponseRecorder();
    const saveAdminConfig = vi.fn();

    await handleUpdateDailyPuzzleAdminConfig({
      request: {
        headers: {},
        body: { enabled: false }
      },
      response,
      logger,
      adminKey: "expected-key",
      loadCurrentAdminConfig: async () => ({ enabled: true, pushEnabled: true }),
      saveAdminConfig
    });

    expect(payload.statusCode).toBe(401);
    expect(payload.body).toEqual({ error: "Unauthorized" });
    expect(saveAdminConfig).not.toHaveBeenCalled();
  });

  it("returns 500 when admin key secret is not configured", async () => {
    const logger = createLogger();
    const { response, payload } = createResponseRecorder();
    const saveAdminConfig = vi.fn();

    await handleUpdateDailyPuzzleAdminConfig({
      request: {
        headers: { "x-admin-key": "anything" },
        body: { enabled: false }
      },
      response,
      logger,
      adminKey: "",
      loadCurrentAdminConfig: async () => ({ enabled: true, pushEnabled: true }),
      saveAdminConfig
    });

    expect(payload.statusCode).toBe(500);
    expect(payload.body).toEqual({ error: "Admin key is not configured" });
    expect(saveAdminConfig).not.toHaveBeenCalled();
  });

  it("returns 400 when no valid boolean fields are provided", async () => {
    const logger = createLogger();
    const { response, payload } = createResponseRecorder();
    const saveAdminConfig = vi.fn();

    await handleUpdateDailyPuzzleAdminConfig({
      request: {
        headers: { "x-admin-key": "expected-key" },
        body: { enabled: "false" }
      },
      response,
      logger,
      adminKey: "expected-key",
      loadCurrentAdminConfig: async () => ({ enabled: true, pushEnabled: true }),
      saveAdminConfig
    });

    expect(payload.statusCode).toBe(400);
    expect(payload.body).toEqual({
      error: "Provide at least one boolean field: enabled, pushEnabled"
    });
    expect(saveAdminConfig).not.toHaveBeenCalled();
  });

  it("updates only provided boolean fields and persists merged config", async () => {
    const logger = createLogger();
    const { response, payload } = createResponseRecorder();
    const saveAdminConfig = vi.fn();

    await handleUpdateDailyPuzzleAdminConfig({
      request: {
        headers: { "x-admin-key": "expected-key" },
        body: { pushEnabled: false }
      },
      response,
      logger,
      adminKey: "expected-key",
      loadCurrentAdminConfig: async () => ({ enabled: true, pushEnabled: true }),
      saveAdminConfig
    });

    expect(payload.statusCode).toBe(200);
    expect(payload.body).toEqual({ enabled: true, pushEnabled: false });
    expect(saveAdminConfig).toHaveBeenCalledWith({ enabled: true, pushEnabled: false });
  });
});

describe("handleSendDailyPuzzleTestPush", () => {
  it("returns 500 when admin key secret is not configured", async () => {
    const logger = createLogger();
    const { response, payload } = createResponseRecorder();
    const sendPush = vi.fn();

    await handleSendDailyPuzzleTestPush({
      request: { headers: { "x-admin-key": "any" } },
      response,
      logger,
      adminKey: "",
      loadLatestPuzzle: async () => samplePuzzle,
      formatPushBody: () => "🚢 + 🧊 + ❤️ = ______",
      sendPush
    });

    expect(payload.statusCode).toBe(500);
    expect(payload.body).toEqual({ error: "Admin key is not configured" });
    expect(sendPush).not.toHaveBeenCalled();
  });

  it("returns 401 when admin key is invalid", async () => {
    const logger = createLogger();
    const { response, payload } = createResponseRecorder();
    const sendPush = vi.fn();

    await handleSendDailyPuzzleTestPush({
      request: { headers: { "x-admin-key": "wrong" } },
      response,
      logger,
      adminKey: "expected-key",
      loadLatestPuzzle: async () => samplePuzzle,
      formatPushBody: () => "🚢 + 🧊 + ❤️ = ______",
      sendPush
    });

    expect(payload.statusCode).toBe(401);
    expect(payload.body).toEqual({ error: "Unauthorized" });
    expect(sendPush).not.toHaveBeenCalled();
  });

  it("returns 404 when latest puzzle does not exist", async () => {
    const logger = createLogger();
    const { response, payload } = createResponseRecorder();
    const sendPush = vi.fn();

    await handleSendDailyPuzzleTestPush({
      request: { headers: { "x-admin-key": "expected-key" } },
      response,
      logger,
      adminKey: "expected-key",
      loadLatestPuzzle: async () => null,
      formatPushBody: () => "🚢 + 🧊 + ❤️ = ______",
      sendPush
    });

    expect(payload.statusCode).toBe(404);
    expect(payload.body).toEqual({ error: "Latest puzzle not found" });
    expect(sendPush).not.toHaveBeenCalled();
  });

  it("sends test push for latest puzzle", async () => {
    const logger = createLogger();
    const { response, payload } = createResponseRecorder();
    const sendPush = vi.fn();

    await handleSendDailyPuzzleTestPush({
      request: { headers: { "x-admin-key": "expected-key" } },
      response,
      logger,
      adminKey: "expected-key",
      loadLatestPuzzle: async () => samplePuzzle,
      formatPushBody: () => "🚢 + 🧊 + ❤️ = ______",
      sendPush
    });

    expect(sendPush).toHaveBeenCalledWith(samplePuzzle, "🚢 + 🧊 + ❤️ = ______");
    expect(payload.statusCode).toBe(200);
    expect(payload.body).toEqual({
      ok: true,
      puzzle_id: samplePuzzle.puzzle_id
    });
  });

  it("returns 500 when push send fails", async () => {
    const logger = createLogger();
    const { response, payload } = createResponseRecorder();
    const sendPush = vi.fn(async () => {
      throw new Error("push failure");
    });

    await handleSendDailyPuzzleTestPush({
      request: { headers: { "x-admin-key": "expected-key" } },
      response,
      logger,
      adminKey: "expected-key",
      loadLatestPuzzle: async () => samplePuzzle,
      formatPushBody: () => "🚢 + 🧊 + ❤️ = ______",
      sendPush
    });

    expect(payload.statusCode).toBe(500);
    expect(payload.body).toEqual({ error: "Failed to send test push" });
    expect(logger.error).toHaveBeenCalled();
  });
});
