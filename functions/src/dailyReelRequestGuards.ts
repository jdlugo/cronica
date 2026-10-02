import { createHash } from "node:crypto";
import type { Firestore } from "firebase-admin/firestore";
import type { DailyReelSecurity } from "./dailyReelSecurity.js";

export type DailyReelGuardedRoute =
  | "session.start"
  | "session.read"
  | "session.mutate"
  | "challenge.create"
  | "challenge.claim"
  | "challenge.read";

export interface DailyReelAppCheckPrincipal {
  appId: string;
}

export interface DailyReelAppCheckVerifier {
  verify(token: string): Promise<DailyReelAppCheckPrincipal>;
}

export interface DailyReelRateLimitPolicy {
  limit: number;
  windowMs: number;
}

export interface DailyReelRateLimitStore {
  consume(input: {
    key: string;
    limit: number;
    windowMs: number;
    now: number;
  }): Promise<{ allowed: boolean; remaining: number; retryAfterMs: number }>;
}

export const DAILY_REEL_RATE_LIMITS: Record<DailyReelGuardedRoute, DailyReelRateLimitPolicy> = {
  "session.start": { limit: 12, windowMs: 60_000 },
  "session.read": { limit: 60, windowMs: 60_000 },
  "session.mutate": { limit: 90, windowMs: 60_000 },
  "challenge.create": { limit: 6, windowMs: 60 * 60_000 },
  "challenge.claim": { limit: 12, windowMs: 60 * 60_000 },
  "challenge.read": { limit: 120, windowMs: 60_000 },
};

export class DailyReelGuardError extends Error {
  constructor(readonly code: string, message: string, readonly retryAfterMs?: number) {
    super(message);
  }
}

export class InMemoryDailyReelRateLimitStore implements DailyReelRateLimitStore {
  private readonly counters = new Map<string, { count: number; resetAt: number }>();

  async consume(input: {
    key: string;
    limit: number;
    windowMs: number;
    now: number;
  }): Promise<{ allowed: boolean; remaining: number; retryAfterMs: number }> {
    const existing = this.counters.get(input.key);
    const counter = !existing || input.now >= existing.resetAt
      ? { count: 0, resetAt: input.now + input.windowMs }
      : existing;
    counter.count += 1;
    this.counters.set(input.key, counter);
    return {
      allowed: counter.count <= input.limit,
      remaining: Math.max(0, input.limit - counter.count),
      retryAfterMs: Math.max(0, counter.resetAt - input.now),
    };
  }
}

export class FirestoreDailyReelRateLimitStore implements DailyReelRateLimitStore {
  constructor(private readonly firestore: Firestore) {}

  async consume(input: {
    key: string;
    limit: number;
    windowMs: number;
    now: number;
  }): Promise<{ allowed: boolean; remaining: number; retryAfterMs: number }> {
    const windowStart = Math.floor(input.now / input.windowMs) * input.windowMs;
    const resetAt = windowStart + input.windowMs;
    const documentId = createHash("sha256").update(`${input.key}:${windowStart}`).digest("hex");
    const reference = this.firestore.collection("dailyReelRateLimits").doc(documentId);
    return this.firestore.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(reference);
      const count = snapshot.exists ? Number(snapshot.get("count")) + 1 : 1;
      transaction.set(reference, { count, resetAt, deleteAt: resetAt + input.windowMs });
      return {
        allowed: count <= input.limit,
        remaining: Math.max(0, input.limit - count),
        retryAfterMs: Math.max(0, resetAt - input.now),
      };
    });
  }
}

export class DailyReelRequestGuard {
  constructor(
    private readonly verifier: DailyReelAppCheckVerifier,
    private readonly limiter: DailyReelRateLimitStore,
    private readonly security: DailyReelSecurity,
    private readonly allowedAppIds: ReadonlySet<string>,
    private readonly now: () => number = Date.now,
  ) {}

  async authorize(input: {
    route: DailyReelGuardedRoute;
    appCheckToken: string;
    anonymousId: string;
  }): Promise<{ appId: string; anonymousIdHash: string; remaining: number }> {
    if (!input.appCheckToken) throw new DailyReelGuardError("app_check.required", "App Check token is required");
    if (!input.anonymousId || input.anonymousId.length > 256) {
      throw new DailyReelGuardError("identity.invalid", "Anonymous installation id is invalid");
    }
    let principal: DailyReelAppCheckPrincipal;
    try {
      principal = await this.verifier.verify(input.appCheckToken);
    } catch {
      throw new DailyReelGuardError("app_check.invalid", "App Check verification failed");
    }
    if (!this.allowedAppIds.has(principal.appId)) {
      throw new DailyReelGuardError("app_check.wrong_app", "App Check token belongs to another app");
    }
    const anonymousIdHash = this.security.hashAnonymousId(input.anonymousId);
    const policy = DAILY_REEL_RATE_LIMITS[input.route];
    const result = await this.limiter.consume({
      key: `${principal.appId}:${input.route}:${anonymousIdHash}`,
      limit: policy.limit,
      windowMs: policy.windowMs,
      now: this.now(),
    });
    if (!result.allowed) {
      throw new DailyReelGuardError("rate_limit.exceeded", "Too many requests", result.retryAfterMs);
    }
    return { appId: principal.appId, anonymousIdHash, remaining: result.remaining };
  }
}
