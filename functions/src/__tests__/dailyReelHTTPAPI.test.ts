import { describe, expect, it, vi } from "vitest";
import type { DailyReelChallengeHandlers } from "../dailyReelChallengeHandlers.js";
import { DailyReelHTTPAPI } from "../dailyReelHTTPAPI.js";
import {
  DailyReelRequestGuard,
  InMemoryDailyReelRateLimitStore,
  type DailyReelAppCheckVerifier,
} from "../dailyReelRequestGuards.js";
import { DailyReelSecurity } from "../dailyReelSecurity.js";
import type { DailyReelSessionService } from "../dailyReelSessions.js";

class TestVerifier implements DailyReelAppCheckVerifier {
  async verify(token: string) {
    if (token !== "valid-token") throw new Error("invalid");
    return { appId: "firebase-app-id" };
  }
}

class TestResponse {
  statusCode = 0;
  body: unknown;

  status(code: number) {
    this.statusCode = code;
    return this;
  }

  json(body: unknown) {
    this.body = body;
    return body;
  }
}

function setup() {
  const start = vi.fn(async (input: unknown) => ({ capability: "cap", session: { input } }));
  const resume = vi.fn(async () => ({ sessionId: "session-1" }));
  const submitAttempt = vi.fn(async (input: unknown) => ({ disposition: "accepted", input }));
  const requestAssist = vi.fn(async (input: unknown) => ({ disposition: "accepted", input }));
  const reveal = vi.fn(async (input: unknown) => ({ disposition: "accepted", input }));
  const sessions = { start, resume, submitAttempt, requestAssist, reveal } as unknown as DailyReelSessionService;
  const challenges = {
    create: vi.fn(),
    preview: vi.fn(),
    claim: vi.fn(),
    refresh: vi.fn(),
  } as unknown as DailyReelChallengeHandlers;
  const guard = new DailyReelRequestGuard(
    new TestVerifier(),
    new InMemoryDailyReelRateLimitStore(),
    new DailyReelSecurity("daily-reel-http-test-secret-at-least-32-bytes"),
    new Set(["firebase-app-id"]),
  );
  const internalErrors: unknown[] = [];
  const api = new DailyReelHTTPAPI(sessions, challenges, guard, (error) => internalErrors.push(error));
  return { api, start, resume, submitAttempt, requestAssist, reveal, internalErrors };
}

function request(path: string, body: Record<string, unknown>, token = "valid-token") {
  return {
    method: "POST",
    path,
    headers: { "x-firebase-appcheck": token },
    body: { anonymousId: "install-1", ...body },
  };
}

describe("DailyReelHTTPAPI", () => {
  it("verifies App Check before invoking session services", async () => {
    const context = setup();
    const response = new TestResponse();
    await context.api.handle(request("/daily-reel/session/start", {
      publicationId: "2026-08-28",
      locale: "en",
    }, "invalid-token"), response);
    expect(response.statusCode).toBe(401);
    expect(response.body).toMatchObject({ code: "app_check.invalid" });
    expect(context.start).not.toHaveBeenCalled();
  });

  it("allows only public start fields and ignores a client-supplied frozen config", async () => {
    const context = setup();
    const response = new TestResponse();
    await context.api.handle(request("/daily-reel/session/start", {
      publicationId: "2026-08-28",
      locale: "fr-FR",
      mode: "daily",
      experienceResolution: { eligible: true, assignmentSource: "challenge" },
    }), response);
    expect(response.statusCode).toBe(200);
    expect(context.start).toHaveBeenCalledWith({
      anonymousId: "install-1",
      publicationId: "2026-08-28",
      locale: "fr-FR",
      mode: "daily",
      scopeId: undefined,
    });
  });

  it("maps the public clue name to the approved server assist id", async () => {
    const context = setup();
    const response = new TestResponse();
    await context.api.handle(request("/daily-reel/session/assist", {
      capability: "opaque-capability",
      expectedSequence: 2,
      requestId: "request-12345678",
      kind: "titleLength",
    }), response);
    expect(response.statusCode).toBe(200);
    expect(context.requestAssist).toHaveBeenCalledWith({
      capability: "opaque-capability",
      expectedSequence: 2,
      requestId: "request-12345678",
      assistId: "title-length",
    });
  });

  it("rejects invalid modes instead of forwarding arbitrary session scopes", async () => {
    const context = setup();
    const response = new TestResponse();
    await context.api.handle(request("/daily-reel/session/start", {
      publicationId: "2026-08-28",
      locale: "en",
      mode: "challenge",
    }), response);
    expect(response.statusCode).toBe(400);
    expect(context.start).not.toHaveBeenCalled();
  });

  it("sanitizes unknown failures while preserving internal diagnostics", async () => {
    const context = setup();
    context.resume.mockRejectedValueOnce(new Error("database internals"));
    const response = new TestResponse();
    await context.api.handle(request("/daily-reel/session/resume", {
      capability: "opaque-capability",
    }), response);
    expect(response.statusCode).toBe(500);
    expect(response.body).toEqual({ code: "internal", message: "Daily Reel request failed" });
    expect(context.internalErrors).toHaveLength(1);
  });
});
