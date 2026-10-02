import type { Firestore } from "firebase-admin/firestore";
import type { DailyReelSecurity } from "./dailyReelSecurity.js";

export const DAILY_REEL_CHALLENGE_TTL_MS = 48 * 60 * 60 * 1_000;
export const DAILY_REEL_ACTIVE_CLAIM_GRACE_MS = 2 * 60 * 60 * 1_000;
export const DAILY_REEL_CHALLENGE_COLLECTION = "dailyReelChallenges";

export type DailyReelFrozenConfig = Readonly<Record<string, unknown>>;

export interface DailyReelCompletedSessionSnapshot {
  sessionId: string;
  anonymousIdHash: string;
  publicationId: string;
  versionId: string;
  locale: string;
  totalScore: number;
  completedAt: number;
  experienceConfig: DailyReelFrozenConfig;
  experienceConfigHash: string;
}

export interface DailyReelChallengeSessionGateway {
  getCompletedSession(input: {
    capability: string;
    anonymousIdHash: string;
  }): Promise<DailyReelCompletedSessionSnapshot | null>;
  startChallengeSession(input: {
    anonymousId: string;
    publicationId: string;
    versionId: string;
    locale: string;
    challengeId: string;
    experienceConfig: DailyReelFrozenConfig;
    experienceConfigHash: string;
    expiresAt: number;
  }): Promise<{ sessionId: string; capability: string }>;
  getSessionOutcome(input: { sessionId: string; capabilityHash: string }): Promise<{
    completed: boolean;
    totalScore?: number;
    completedAt?: number;
  }>;
}

export interface DailyReelChallengeRecord {
  challengeId: string;
  capabilityHash: string;
  creatorAnonymousIdHash: string;
  sourceSessionId: string;
  publicationId: string;
  versionId: string;
  locale: string;
  senderScore: number;
  senderNickname?: string;
  experienceConfig: DailyReelFrozenConfig;
  experienceConfigHash: string;
  createdAt: number;
  expiresAt: number;
  claimedByAnonymousIdHash?: string;
  claimedAt?: number;
  claimGraceUntil?: number;
  opponentSessionId?: string;
  opponentCapabilityHash?: string;
  opponentScore?: number;
  completedAt?: number;
}

export type DailyReelClaimReservation =
  | { status: "reserved" | "existing"; record: DailyReelChallengeRecord }
  | { status: "claimed" | "expired"; record: DailyReelChallengeRecord };

export interface DailyReelChallengeStore {
  get(challengeId: string): Promise<DailyReelChallengeRecord | null>;
  createIfAbsent(record: DailyReelChallengeRecord): Promise<DailyReelChallengeRecord>;
  reserveClaim(input: {
    challengeId: string;
    claimantAnonymousIdHash: string;
    now: number;
    graceMs: number;
  }): Promise<DailyReelClaimReservation>;
  attachOpponentSession(input: {
    challengeId: string;
    claimantAnonymousIdHash: string;
    sessionId: string;
    capabilityHash: string;
  }): Promise<DailyReelChallengeRecord>;
  complete(input: {
    challengeId: string;
    sessionId: string;
    opponentScore: number;
    completedAt: number;
  }): Promise<DailyReelChallengeRecord>;
}

export class DailyReelChallengeError extends Error {
  constructor(readonly code: string, message: string) {
    super(message);
  }
}

export class InMemoryDailyReelChallengeStore implements DailyReelChallengeStore {
  private readonly records = new Map<string, DailyReelChallengeRecord>();

  async get(challengeId: string): Promise<DailyReelChallengeRecord | null> {
    return this.records.get(challengeId) ?? null;
  }

  async createIfAbsent(record: DailyReelChallengeRecord): Promise<DailyReelChallengeRecord> {
    const existing = this.records.get(record.challengeId);
    if (existing) return existing;
    this.records.set(record.challengeId, record);
    return record;
  }

  async reserveClaim(input: {
    challengeId: string;
    claimantAnonymousIdHash: string;
    now: number;
    graceMs: number;
  }): Promise<DailyReelClaimReservation> {
    const record = this.records.get(input.challengeId);
    if (!record) throw new DailyReelChallengeError("challenge.not_found", "Challenge was not found");
    if (!record.claimedByAnonymousIdHash && input.now >= record.expiresAt) {
      return { status: "expired", record };
    }
    if (record.claimedByAnonymousIdHash && record.claimedByAnonymousIdHash !== input.claimantAnonymousIdHash) {
      return { status: "claimed", record };
    }
    if (record.claimedByAnonymousIdHash === input.claimantAnonymousIdHash) {
      if (input.now > (record.claimGraceUntil ?? record.expiresAt)) return { status: "expired", record };
      return { status: "existing", record };
    }

    const claimed: DailyReelChallengeRecord = {
      ...record,
      claimedByAnonymousIdHash: input.claimantAnonymousIdHash,
      claimedAt: input.now,
      claimGraceUntil: Math.max(record.expiresAt, input.now + input.graceMs),
    };
    this.records.set(input.challengeId, claimed);
    return { status: "reserved", record: claimed };
  }

  async attachOpponentSession(input: {
    challengeId: string;
    claimantAnonymousIdHash: string;
    sessionId: string;
    capabilityHash: string;
  }): Promise<DailyReelChallengeRecord> {
    const record = this.records.get(input.challengeId);
    if (!record) throw new DailyReelChallengeError("challenge.not_found", "Challenge was not found");
    if (record.claimedByAnonymousIdHash !== input.claimantAnonymousIdHash) {
      throw new DailyReelChallengeError("challenge.claim_mismatch", "Challenge belongs to another installation");
    }
    if (record.opponentSessionId && record.opponentSessionId !== input.sessionId) {
      throw new DailyReelChallengeError("challenge.session_conflict", "Challenge already has a different session");
    }
    const attached = {
      ...record,
      opponentSessionId: input.sessionId,
      opponentCapabilityHash: input.capabilityHash,
    };
    this.records.set(input.challengeId, attached);
    return attached;
  }

  async complete(input: {
    challengeId: string;
    sessionId: string;
    opponentScore: number;
    completedAt: number;
  }): Promise<DailyReelChallengeRecord> {
    const record = this.records.get(input.challengeId);
    if (!record) throw new DailyReelChallengeError("challenge.not_found", "Challenge was not found");
    if (record.opponentSessionId !== input.sessionId) {
      throw new DailyReelChallengeError("challenge.session_mismatch", "Completion does not match this challenge");
    }
    if (record.completedAt) return record;
    const completed = {
      ...record,
      opponentScore: input.opponentScore,
      completedAt: input.completedAt,
    };
    this.records.set(input.challengeId, completed);
    return completed;
  }
}

export class FirestoreDailyReelChallengeStore implements DailyReelChallengeStore {
  constructor(private readonly firestore: Firestore) {}

  async get(challengeId: string): Promise<DailyReelChallengeRecord | null> {
    const snapshot = await this.document(challengeId).get();
    return snapshot.exists ? snapshot.data() as DailyReelChallengeRecord : null;
  }

  async createIfAbsent(record: DailyReelChallengeRecord): Promise<DailyReelChallengeRecord> {
    return this.firestore.runTransaction(async (transaction) => {
      const reference = this.document(record.challengeId);
      const snapshot = await transaction.get(reference);
      if (snapshot.exists) return snapshot.data() as DailyReelChallengeRecord;
      transaction.create(reference, record);
      return record;
    });
  }

  async reserveClaim(input: {
    challengeId: string;
    claimantAnonymousIdHash: string;
    now: number;
    graceMs: number;
  }): Promise<DailyReelClaimReservation> {
    return this.firestore.runTransaction(async (transaction) => {
      const reference = this.document(input.challengeId);
      const snapshot = await transaction.get(reference);
      if (!snapshot.exists) throw new DailyReelChallengeError("challenge.not_found", "Challenge was not found");
      const record = snapshot.data() as DailyReelChallengeRecord;
      if (!record.claimedByAnonymousIdHash && input.now >= record.expiresAt) {
        return { status: "expired", record };
      }
      if (record.claimedByAnonymousIdHash && record.claimedByAnonymousIdHash !== input.claimantAnonymousIdHash) {
        return { status: "claimed", record };
      }
      if (record.claimedByAnonymousIdHash === input.claimantAnonymousIdHash) {
        if (input.now > (record.claimGraceUntil ?? record.expiresAt)) return { status: "expired", record };
        return { status: "existing", record };
      }
      const claimed: DailyReelChallengeRecord = {
        ...record,
        claimedByAnonymousIdHash: input.claimantAnonymousIdHash,
        claimedAt: input.now,
        claimGraceUntil: Math.max(record.expiresAt, input.now + input.graceMs),
      };
      transaction.update(reference, {
        claimedByAnonymousIdHash: claimed.claimedByAnonymousIdHash,
        claimedAt: claimed.claimedAt,
        claimGraceUntil: claimed.claimGraceUntil,
      });
      return { status: "reserved", record: claimed };
    });
  }

  async attachOpponentSession(input: {
    challengeId: string;
    claimantAnonymousIdHash: string;
    sessionId: string;
    capabilityHash: string;
  }): Promise<DailyReelChallengeRecord> {
    return this.firestore.runTransaction(async (transaction) => {
      const reference = this.document(input.challengeId);
      const snapshot = await transaction.get(reference);
      if (!snapshot.exists) throw new DailyReelChallengeError("challenge.not_found", "Challenge was not found");
      const record = snapshot.data() as DailyReelChallengeRecord;
      if (record.claimedByAnonymousIdHash !== input.claimantAnonymousIdHash) {
        throw new DailyReelChallengeError("challenge.claim_mismatch", "Challenge belongs to another installation");
      }
      if (record.opponentSessionId && record.opponentSessionId !== input.sessionId) {
        throw new DailyReelChallengeError("challenge.session_conflict", "Challenge already has a different session");
      }
      const attached = {
        ...record,
        opponentSessionId: input.sessionId,
        opponentCapabilityHash: input.capabilityHash,
      };
      transaction.update(reference, {
        opponentSessionId: input.sessionId,
        opponentCapabilityHash: input.capabilityHash,
      });
      return attached;
    });
  }

  async complete(input: {
    challengeId: string;
    sessionId: string;
    opponentScore: number;
    completedAt: number;
  }): Promise<DailyReelChallengeRecord> {
    return this.firestore.runTransaction(async (transaction) => {
      const reference = this.document(input.challengeId);
      const snapshot = await transaction.get(reference);
      if (!snapshot.exists) throw new DailyReelChallengeError("challenge.not_found", "Challenge was not found");
      const record = snapshot.data() as DailyReelChallengeRecord;
      if (record.opponentSessionId !== input.sessionId) {
        throw new DailyReelChallengeError("challenge.session_mismatch", "Completion does not match this challenge");
      }
      if (record.completedAt) return record;
      const completed = { ...record, opponentScore: input.opponentScore, completedAt: input.completedAt };
      transaction.update(reference, { opponentScore: input.opponentScore, completedAt: input.completedAt });
      return completed;
    });
  }

  private document(challengeId: string) {
    return this.firestore.collection(DAILY_REEL_CHALLENGE_COLLECTION).doc(challengeId);
  }
}

export interface DailyReelChallengeProjection {
  challengeId: string;
  status: "available" | "claimed" | "completed" | "expired";
  publicationId: string;
  locale: string;
  senderNickname?: string;
  senderScore?: number;
  opponentScore?: number;
  experienceConfigHash: string;
  expiresAt: number;
}

export class DailyReelChallengeService {
  constructor(
    private readonly store: DailyReelChallengeStore,
    private readonly sessions: DailyReelChallengeSessionGateway,
    private readonly security: DailyReelSecurity,
    private readonly shareBaseUrl: string,
    private readonly now: () => number = Date.now,
  ) {}

  async create(input: {
    sourceSessionCapability: string;
    anonymousId: string;
    requestId: string;
    nickname?: string;
  }): Promise<{ challengeId: string; capability: string; shareUrl: string; expiresAt: number }> {
    assertRequestId(input.requestId);
    const anonymousIdHash = this.security.hashAnonymousId(input.anonymousId);
    const source = await this.sessions.getCompletedSession({
      capability: input.sourceSessionCapability,
      anonymousIdHash,
    });
    if (!source || source.anonymousIdHash !== anonymousIdHash) {
      throw new DailyReelChallengeError("challenge.session_incomplete", "Complete the Reel before creating a challenge");
    }
    const capability = this.security.deriveChallengeCapability({
      sessionId: source.sessionId,
      requestId: input.requestId,
    });
    const challengeId = this.security.hashCapability(capability);
    const createdAt = this.now();
    const senderNickname = sanitizeDailyReelNickname(input.nickname);
    const record: DailyReelChallengeRecord = {
      challengeId,
      capabilityHash: challengeId,
      creatorAnonymousIdHash: anonymousIdHash,
      sourceSessionId: source.sessionId,
      publicationId: source.publicationId,
      versionId: source.versionId,
      locale: source.locale,
      senderScore: source.totalScore,
      ...(senderNickname ? { senderNickname } : {}),
      experienceConfig: cloneConfig(source.experienceConfig),
      experienceConfigHash: source.experienceConfigHash,
      createdAt,
      expiresAt: createdAt + DAILY_REEL_CHALLENGE_TTL_MS,
    };
    const stored = await this.store.createIfAbsent(record);
    if (stored.creatorAnonymousIdHash !== anonymousIdHash || stored.sourceSessionId !== source.sessionId) {
      throw new DailyReelChallengeError("challenge.conflict", "Challenge idempotency key was already used");
    }
    return {
      challengeId,
      capability,
      shareUrl: dailyReelChallengeShareUrl(this.shareBaseUrl, capability),
      expiresAt: stored.expiresAt,
    };
  }

  async preview(capability: string): Promise<DailyReelChallengeProjection> {
    return this.project(await this.requireRecord(capability));
  }

  async claim(input: {
    capability: string;
    anonymousId: string;
  }): Promise<{ sessionId: string; sessionCapability: string; challenge: DailyReelChallengeProjection }> {
    const challengeId = this.security.hashCapability(input.capability);
    const record = await this.requireRecord(input.capability);
    const claimantAnonymousIdHash = this.security.hashAnonymousId(input.anonymousId);
    if (record.creatorAnonymousIdHash === claimantAnonymousIdHash) {
      throw new DailyReelChallengeError("challenge.self_claim", "Open this challenge on a friend's installation");
    }
    const reservation = await this.store.reserveClaim({
      challengeId,
      claimantAnonymousIdHash,
      now: this.now(),
      graceMs: DAILY_REEL_ACTIVE_CLAIM_GRACE_MS,
    });
    if (reservation.status === "claimed") {
      throw new DailyReelChallengeError("challenge.already_claimed", "Another installation claimed this challenge");
    }
    if (reservation.status === "expired") {
      throw new DailyReelChallengeError("challenge.expired", "This challenge has expired");
    }
    const session = await this.sessions.startChallengeSession({
      anonymousId: input.anonymousId,
      publicationId: reservation.record.publicationId,
      versionId: reservation.record.versionId,
      locale: reservation.record.locale,
      challengeId,
      experienceConfig: cloneConfig(reservation.record.experienceConfig),
      experienceConfigHash: reservation.record.experienceConfigHash,
      expiresAt: reservation.record.claimGraceUntil ?? reservation.record.expiresAt,
    });
    const attached = await this.store.attachOpponentSession({
      challengeId,
      claimantAnonymousIdHash,
      sessionId: session.sessionId,
      capabilityHash: this.security.hashCapability(session.capability),
    });
    return {
      sessionId: session.sessionId,
      sessionCapability: session.capability,
      challenge: this.project(attached),
    };
  }

  async refresh(capability: string): Promise<DailyReelChallengeProjection> {
    const record = await this.requireRecord(capability);
    if (!record.opponentSessionId || record.completedAt) return this.project(record);
    if (!record.opponentCapabilityHash) return this.project(record);
    const outcome = await this.sessions.getSessionOutcome({
      sessionId: record.opponentSessionId,
      capabilityHash: record.opponentCapabilityHash,
    });
    if (!outcome.completed || outcome.totalScore === undefined || outcome.completedAt === undefined) {
      return this.project(record);
    }
    const completed = await this.store.complete({
      challengeId: record.challengeId,
      sessionId: record.opponentSessionId,
      opponentScore: outcome.totalScore,
      completedAt: outcome.completedAt,
    });
    return this.project(completed);
  }

  private async requireRecord(capability: string): Promise<DailyReelChallengeRecord> {
    if (!capability) throw new DailyReelChallengeError("challenge.invalid_capability", "Challenge capability is required");
    const record = await this.store.get(this.security.hashCapability(capability));
    if (!record) throw new DailyReelChallengeError("challenge.not_found", "Challenge was not found");
    return record;
  }

  private project(record: DailyReelChallengeRecord): DailyReelChallengeProjection {
    const completed = record.completedAt !== undefined && record.opponentScore !== undefined;
    const activeUntil = record.claimGraceUntil ?? record.expiresAt;
    const expired = !completed && this.now() >= activeUntil;
    return {
      challengeId: record.challengeId,
      status: completed ? "completed" : expired ? "expired" : record.claimedByAnonymousIdHash ? "claimed" : "available",
      publicationId: record.publicationId,
      locale: record.locale,
      ...(record.senderNickname ? { senderNickname: record.senderNickname } : {}),
      ...(completed ? { senderScore: record.senderScore, opponentScore: record.opponentScore } : {}),
      experienceConfigHash: record.experienceConfigHash,
      expiresAt: activeUntil,
    };
  }
}

export function dailyReelChallengeShareUrl(baseUrl: string, capability: string): string {
  const url = new URL("/c", baseUrl);
  url.hash = `capability=${encodeURIComponent(capability)}`;
  return url.toString();
}

export function sanitizeDailyReelNickname(value?: string): string | undefined {
  if (!value) return undefined;
  const normalized = value
    .normalize("NFKC")
    .replace(/[\u0000-\u001f\u007f-\u009f\u202a-\u202e\u2066-\u2069]/g, "")
    .replace(/[^\p{L}\p{N}\p{M} ._'\-]/gu, "")
    .replace(/\s+/g, " ")
    .trim();
  const shortened = Array.from(normalized).slice(0, 24).join("");
  return shortened || undefined;
}

function assertRequestId(requestId: string): void {
  if (!/^[A-Za-z0-9_-]{8,128}$/.test(requestId)) {
    throw new DailyReelChallengeError("challenge.invalid_request_id", "Request id is invalid");
  }
}

function cloneConfig(config: DailyReelFrozenConfig): DailyReelFrozenConfig {
  return structuredClone(config) as DailyReelFrozenConfig;
}
