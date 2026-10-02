import type { DailyReelChallengeHandlers } from "./dailyReelChallengeHandlers.js";
import { DailyReelChallengeError } from "./dailyReelChallenges.js";
import { DailyReelGuardError, type DailyReelRequestGuard } from "./dailyReelRequestGuards.js";
import { DailyReelSessionError, type DailyReelSessionService } from "./dailyReelSessions.js";

interface HTTPRequest {
  method?: string;
  path: string;
  headers: Record<string, string | string[] | undefined>;
  body?: unknown;
}

interface HTTPResponse {
  status(code: number): HTTPResponse;
  json(body: unknown): unknown;
}

export class DailyReelHTTPAPI {
  constructor(
    private readonly sessions: DailyReelSessionService,
    private readonly challenges: DailyReelChallengeHandlers,
    private readonly guard: DailyReelRequestGuard,
    private readonly onInternalError: (error: unknown) => void = () => {},
  ) {}

  async handle(request: HTTPRequest, response: HTTPResponse): Promise<void> {
    if (request.method !== "POST") {
      response.status(405).json({ code: "method_not_allowed", message: "POST is required" });
      return;
    }
    try {
      const body = objectBody(request.body);
      const appCheckToken = header(request.headers, "x-firebase-appcheck");
      const anonymousId = stringField(body, "anonymousId");
      let result: unknown;
      switch (normalizePath(request.path)) {
      case "/daily-reel/session/start": {
        await this.authorize("session.start", appCheckToken, anonymousId);
        const mode = optionalString(body, "mode");
        if (mode !== undefined && mode !== "daily" && mode !== "encore" && mode !== "practice") {
          throw new HTTPInputError("invalid_mode", "Session mode is invalid");
        }
        result = await this.sessions.start({
          anonymousId,
          publicationId: stringField(body, "publicationId"),
          locale: stringField(body, "locale"),
          mode,
          scopeId: optionalString(body, "scopeId"),
        });
        break;
      }
      case "/daily-reel/session/resume":
        await this.authorize("session.read", appCheckToken, anonymousId);
        result = { session: await this.sessions.resume(stringField(body, "capability")) };
        break;
      case "/daily-reel/session/attempt":
        await this.authorize("session.mutate", appCheckToken, anonymousId);
        result = await this.sessions.submitAttempt({
          capability: stringField(body, "capability"),
          expectedSequence: integerField(body, "expectedSequence"),
          requestId: stringField(body, "requestId"),
          answer: answerField(body, "answer"),
        });
        break;
      case "/daily-reel/session/assist": {
        await this.authorize("session.mutate", appCheckToken, anonymousId);
        const kind = stringField(body, "kind");
        if (kind !== "titleLength" && kind !== "hint") throw new HTTPInputError("invalid_assist", "Assist kind is invalid");
        result = await this.sessions.requestAssist({
          capability: stringField(body, "capability"),
          expectedSequence: integerField(body, "expectedSequence"),
          requestId: stringField(body, "requestId"),
          assistId: kind === "titleLength" ? "title-length" : "standard-hint",
        });
        break;
      }
      case "/daily-reel/session/reveal":
        await this.authorize("session.mutate", appCheckToken, anonymousId);
        result = await this.sessions.reveal({
          capability: stringField(body, "capability"),
          expectedSequence: integerField(body, "expectedSequence"),
          requestId: stringField(body, "requestId"),
        });
        break;
      case "/daily-reel/challenge/create":
        result = await this.challenges.create({
          appCheckToken,
          anonymousId,
          sourceSessionCapability: stringField(body, "sourceSessionCapability"),
          requestId: stringField(body, "requestId"),
          nickname: optionalString(body, "nickname"),
        });
        break;
      case "/daily-reel/challenge/preview":
        result = await this.challenges.preview({
          appCheckToken,
          anonymousId,
          capability: stringField(body, "capability"),
        });
        break;
      case "/daily-reel/challenge/claim":
        result = await this.challenges.claim({
          appCheckToken,
          anonymousId,
          capability: stringField(body, "capability"),
        });
        break;
      case "/daily-reel/challenge/refresh":
        result = await this.challenges.refresh({
          appCheckToken,
          anonymousId,
          capability: stringField(body, "capability"),
        });
        break;
      default:
        response.status(404).json({ code: "route_not_found", message: "Daily Reel route was not found" });
        return;
      }
      response.status(200).json(result);
    } catch (error) {
      const mapped = mapError(error);
      if (mapped.status === 500) this.onInternalError(error);
      response.status(mapped.status).json({ code: mapped.code, message: mapped.message });
    }
  }

  private async authorize(
    route: "session.start" | "session.read" | "session.mutate",
    appCheckToken: string,
    anonymousId: string,
  ) {
    await this.guard.authorize({ route, appCheckToken, anonymousId });
  }
}

class HTTPInputError extends Error {
  constructor(readonly code: string, message: string) { super(message); }
}

function normalizePath(path: string): string {
  const normalized = `/${path}`.replace(/\/+/g, "/");
  return normalized.length > 1 ? normalized.replace(/\/$/, "") : normalized;
}

function objectBody(value: unknown): Record<string, unknown> {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new HTTPInputError("invalid_body", "A JSON object body is required");
  }
  return value as Record<string, unknown>;
}

function stringField(body: Record<string, unknown>, key: string): string {
  const value = body[key];
  if (typeof value !== "string" || !value.trim()) throw new HTTPInputError("invalid_body", `${key} is required`);
  return value;
}

function optionalString(body: Record<string, unknown>, key: string): string | undefined {
  const value = body[key];
  if (value === undefined || value === null || value === "") return undefined;
  if (typeof value !== "string") throw new HTTPInputError("invalid_body", `${key} must be a string`);
  return value;
}

function integerField(body: Record<string, unknown>, key: string): number {
  const value = body[key];
  if (!Number.isInteger(value) || (value as number) < 0) throw new HTTPInputError("invalid_body", `${key} must be a non-negative integer`);
  return value as number;
}

function answerField(body: Record<string, unknown>, key: string): string | string[] {
  const value = body[key];
  if (typeof value === "string" && value.trim()) return value;
  if (Array.isArray(value) && value.length > 0 && value.every((item) => typeof item === "string" && item.length > 0)) {
    return value as string[];
  }
  throw new HTTPInputError("invalid_body", `${key} is invalid`);
}

function header(headers: HTTPRequest["headers"], name: string): string {
  const entry = Object.entries(headers).find(([key]) => key.toLowerCase() === name)?.[1];
  return Array.isArray(entry) ? entry[0] ?? "" : entry ?? "";
}

function mapError(error: unknown): { status: number; code: string; message: string } {
  if (error instanceof HTTPInputError) return { status: 400, code: error.code, message: error.message };
  if (error instanceof DailyReelGuardError) {
    return { status: error.code === "rate_limit.exceeded" ? 429 : 401, code: error.code, message: error.message };
  }
  if (error instanceof DailyReelSessionError || error instanceof DailyReelChallengeError) {
    if (error.code.includes("not_found") || error.code === "content.unavailable") return { status: 404, code: error.code, message: error.message };
    if (error.code.includes("expired")) return { status: 410, code: error.code, message: error.message };
    if (error.code.includes("ineligible") || error.code.includes("self_claim")) return { status: 403, code: error.code, message: error.message };
    if (error.code.includes("claimed") || error.code.includes("conflict") || error.code.includes("mismatch")) return { status: 409, code: error.code, message: error.message };
    return { status: 400, code: error.code, message: error.message };
  }
  return { status: 500, code: "internal", message: "Daily Reel request failed" };
}
