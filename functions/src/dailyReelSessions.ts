import type { Firestore } from "firebase-admin/firestore";
import type { DailyReelPrivate, DailyReelExperienceConfig } from "./dailyReelSchema.js";
import type {
  DailyReelExperienceResolver,
  DailyReelAssignmentSource,
  DailyReelExperienceResolution,
} from "./dailyReelExperience.js";
import { applyDailyReelActEvent, type DailyReelActProgress } from "./dailyReelStateMachine.js";
import { totalDailyReelScore } from "./dailyReelScoring.js";
import type { DailyReelSecurity } from "./dailyReelSecurity.js";
import type { DailyReelPublicationRecord } from "./dailyReelCoverage.js";
import { DAILY_REEL_COLLECTIONS, type DailyReelVersionRecord } from "./dailyReelRepository.js";

const SESSION_COLLECTION = "dailyReelSessions";

type DailyReelPublicAct = DailyReelPrivate["reel"]["localized"]["en"]["acts"][number];
type DailyReelActRole = "decode" | "connect" | "arrange";
type DailyReelSessionMode = "daily" | "challenge" | "encore" | "practice";

export interface DailyReelPublishedContent {
  publicationId: string;
  versionId: string;
  privateReel: DailyReelPrivate;
}

export interface DailyReelContentStore {
  getPublished(publicationId: string): Promise<DailyReelPublishedContent | null>;
  getVersion(versionId: string): Promise<DailyReelPublishedContent | null>;
}

export interface DailyReelSessionActProgress extends DailyReelActProgress {
  actId: string;
  role: DailyReelActRole;
}

export interface DailyReelSessionRecord {
  sessionId: string;
  capabilityHash: string;
  anonymousIdHash: string;
  publicationId: string;
  versionId: string;
  locale: string;
  mode: DailyReelSessionMode;
  status: "active" | "completed";
  sequence: number;
  currentActIndex: number;
  acts: DailyReelSessionActProgress[];
  totalScore: number;
  config: DailyReelExperienceConfig;
  assignmentSource: DailyReelAssignmentSource;
  createdAt: string;
  updatedAt: string;
  expiresAt: string;
  completedAt: string | null;
  requestLedger: Record<string, DailyReelMutationResponse>;
  requestOrder: string[];
}

export interface DailyReelSessionProjection {
  contractVersion: "daily-reel-session.v1";
  sessionId: string;
  publicationId: string;
  contentVersion: string;
  scoringVersion: "daily-reel-score.v1";
  configId: string;
  assignmentSource: DailyReelAssignmentSource;
  locale: string;
  mode: DailyReelSessionMode;
  status: "active" | "completed";
  sequence: number;
  currentActIndex: number;
  theme: string;
  currentAct: DailyReelPublicAct | null;
  acts: DailyReelSessionActProgress[];
  totalScore: number;
  completedAt: string | null;
}

export interface DailyReelReveal {
  role: DailyReelActRole;
  title?: string;
  correctChoiceId?: string;
  correctOrder?: string[];
  explanation: string;
  threadTitle?: string;
  threadExplanation?: string;
}

export interface DailyReelAssistReveal {
  id: string;
  kind: "titleLength" | "hint";
  scoreImpact: 0 | 1;
  titleLength?: number;
  text?: string;
}

export interface DailyReelMutationResponse {
  disposition: "accepted" | "stale";
  correct: boolean | null;
  actTerminal: boolean;
  reveal: DailyReelReveal | null;
  assist: DailyReelAssistReveal | null;
  session: DailyReelSessionProjection;
}

export interface DailyReelSessionStore {
  get(capabilityHash: string): Promise<DailyReelSessionRecord | null>;
  createIfAbsent(record: DailyReelSessionRecord): Promise<DailyReelSessionRecord>;
  mutate<T>(
    capabilityHash: string,
    mutation: (record: DailyReelSessionRecord) => { record: DailyReelSessionRecord; result: T },
  ): Promise<T>;
}

export class DailyReelSessionError extends Error {
  constructor(readonly code: string, message: string) {
    super(message);
  }
}

export class InMemoryDailyReelContentStore implements DailyReelContentStore {
  private readonly byPublication = new Map<string, DailyReelPublishedContent>();
  private readonly byVersion = new Map<string, DailyReelPublishedContent>();

  put(content: DailyReelPublishedContent): void {
    this.byPublication.set(content.publicationId, clone(content));
    this.byVersion.set(content.versionId, clone(content));
  }

  async getPublished(publicationId: string): Promise<DailyReelPublishedContent | null> {
    return clone(this.byPublication.get(publicationId) ?? null);
  }

  async getVersion(versionId: string): Promise<DailyReelPublishedContent | null> {
    return clone(this.byVersion.get(versionId) ?? null);
  }
}

export class InMemoryDailyReelSessionStore implements DailyReelSessionStore {
  private readonly values = new Map<string, DailyReelSessionRecord>();

  async get(capabilityHash: string): Promise<DailyReelSessionRecord | null> {
    return clone(this.values.get(capabilityHash) ?? null);
  }

  async createIfAbsent(record: DailyReelSessionRecord): Promise<DailyReelSessionRecord> {
    const existing = this.values.get(record.capabilityHash);
    if (existing) return clone(existing);
    this.values.set(record.capabilityHash, clone(record));
    return clone(record);
  }

  async mutate<T>(
    capabilityHash: string,
    mutation: (record: DailyReelSessionRecord) => { record: DailyReelSessionRecord; result: T },
  ): Promise<T> {
    const existing = this.values.get(capabilityHash);
    if (!existing) throw new DailyReelSessionError("session.not_found", "Session was not found");
    const outcome = mutation(clone(existing));
    this.values.set(capabilityHash, clone(outcome.record));
    return clone(outcome.result);
  }
}

export class FirestoreDailyReelContentStore implements DailyReelContentStore {
  constructor(private readonly db: Firestore) {}

  async getPublished(publicationId: string): Promise<DailyReelPublishedContent | null> {
    const publication = await this.db.collection("dailyReelPublications").doc(publicationId).get();
    if (!publication.exists) return null;
    const publicationRecord = publication.data() as DailyReelPublicationRecord;
    const content = await this.getVersion(publicationRecord.versionId);
    if (!content || publicationRecord.source !== "evergreen") return content;
    return rebaseEvergreenDailyReelContent(content, publicationId);
  }

  async getVersion(versionId: string): Promise<DailyReelPublishedContent | null> {
    const version = await this.db.collection(DAILY_REEL_COLLECTIONS.versions).doc(versionId).get();
    if (!version.exists) return null;
    const record = version.data() as DailyReelVersionRecord;
    return {
      publicationId: record.privateReel.reel.publicationId,
      versionId: record.versionId,
      privateReel: record.privateReel,
    };
  }
}

export function rebaseEvergreenDailyReelContent(
  content: DailyReelPublishedContent,
  publicationId: string,
): DailyReelPublishedContent {
  const rebased = clone(content);
  const availableAt = new Date(`${publicationId}T05:00:00.000Z`);
  const expiresAt = new Date(availableAt);
  expiresAt.setUTCDate(expiresAt.getUTCDate() + 1);
  rebased.publicationId = publicationId;
  rebased.privateReel.reel.publicationId = publicationId;
  rebased.privateReel.reel.publicationWindow = {
    availableAt: availableAt.toISOString(),
    expiresAt: expiresAt.toISOString(),
  };
  return rebased;
}

export class FirestoreDailyReelSessionStore implements DailyReelSessionStore {
  constructor(private readonly db: Firestore) {}

  async get(capabilityHash: string): Promise<DailyReelSessionRecord | null> {
    const snapshot = await this.db.collection(SESSION_COLLECTION).doc(capabilityHash).get();
    return snapshot.exists ? (snapshot.data() as DailyReelSessionRecord) : null;
  }

  async createIfAbsent(record: DailyReelSessionRecord): Promise<DailyReelSessionRecord> {
    const reference = this.db.collection(SESSION_COLLECTION).doc(record.capabilityHash);
    return this.db.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(reference);
      if (snapshot.exists) return snapshot.data() as DailyReelSessionRecord;
      transaction.create(reference, record);
      return record;
    });
  }

  async mutate<T>(
    capabilityHash: string,
    mutation: (record: DailyReelSessionRecord) => { record: DailyReelSessionRecord; result: T },
  ): Promise<T> {
    const reference = this.db.collection(SESSION_COLLECTION).doc(capabilityHash);
    return this.db.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(reference);
      if (!snapshot.exists) throw new DailyReelSessionError("session.not_found", "Session was not found");
      const outcome = mutation(snapshot.data() as DailyReelSessionRecord);
      transaction.set(reference, outcome.record);
      return outcome.result;
    });
  }
}

export class DailyReelSessionService {
  constructor(
    private readonly sessions: DailyReelSessionStore,
    private readonly content: DailyReelContentStore,
    private readonly experience: DailyReelExperienceResolver,
    private readonly security: DailyReelSecurity,
    private readonly now: () => Date = () => new Date(),
  ) {}

  async start(input: {
    anonymousId: string;
    publicationId: string;
    locale: string;
    mode?: DailyReelSessionMode;
    scopeId?: string;
    experienceResolution?: DailyReelExperienceResolution;
  }): Promise<{ capability: string; session: DailyReelSessionProjection }> {
    const anonymousIdHash = this.security.hashAnonymousId(input.anonymousId);
    const resolution = input.experienceResolution ?? await this.experience.resolve(anonymousIdHash);
    if (!resolution.eligible || !resolution.config || !resolution.assignmentSource) {
      throw new DailyReelSessionError("experience.ineligible", "Daily Reel is not enabled for this installation");
    }
    const published = await this.content.getPublished(input.publicationId);
    if (!published) throw new DailyReelSessionError("content.unavailable", "Published Reel was not found");

    const mode = input.mode ?? "daily";
    const timestamp = this.now();
    if (mode === "daily") {
      const availableAt = Date.parse(published.privateReel.reel.publicationWindow.availableAt);
      const expiresAt = Date.parse(published.privateReel.reel.publicationWindow.expiresAt);
      if (timestamp.getTime() < availableAt || timestamp.getTime() >= expiresAt) {
        throw new DailyReelSessionError("content.unavailable", "Published Reel is outside its daily window");
      }
    }
    const locale = published.privateReel.reel.supportedLocales.find(
      (supportedLocale) => supportedLocale === input.locale,
    ) ?? published.privateReel.reel.defaultLocale;
    const capability = this.security.deriveSessionCapability({
      anonymousIdHash,
      publicationId: input.publicationId,
      mode,
      scopeId: input.scopeId,
    });
    const capabilityHash = this.security.hashCapability(capability);
    const localized = localizedContent(published.privateReel, locale);
    const record: DailyReelSessionRecord = {
      sessionId: `session-${capabilityHash.slice(0, 24)}`,
      capabilityHash,
      anonymousIdHash,
      publicationId: input.publicationId,
      versionId: published.versionId,
      locale,
      mode,
      status: "active",
      sequence: 0,
      currentActIndex: 0,
      acts: localized.acts.map((act) => ({
        actId: act.id,
        role: act.role,
        status: "playing",
        incorrectAttempts: 0,
        scoreAffectingClues: 0,
        requestedClueIds: [],
        score: null,
      })),
      totalScore: 0,
      config: resolution.config,
      assignmentSource: resolution.assignmentSource,
      createdAt: timestamp.toISOString(),
      updatedAt: timestamp.toISOString(),
      expiresAt: new Date(timestamp.getTime() + 7 * 24 * 60 * 60 * 1000).toISOString(),
      completedAt: null,
      requestLedger: {},
      requestOrder: [],
    };
    const persisted = await this.sessions.createIfAbsent(record);
    assertNotExpired(persisted, timestamp);
    const persistedContent = await this.requireVersion(persisted.versionId);
    return { capability, session: projectSession(persisted, persistedContent.privateReel) };
  }

  async resume(capability: string): Promise<DailyReelSessionProjection> {
    const record = await this.requireSession(capability);
    assertNotExpired(record, this.now());
    const content = await this.requireVersion(record.versionId);
    return projectSession(record, content.privateReel);
  }

  async submitAttempt(input: {
    capability: string;
    requestId: string;
    expectedSequence: number;
    answer: unknown;
  }): Promise<DailyReelMutationResponse> {
    const existing = await this.requireSession(input.capability);
    const content = await this.requireVersion(existing.versionId);
    const capabilityHash = this.security.hashCapability(input.capability);
    return this.sessions.mutate(capabilityHash, (record) => {
      const replay = record.requestLedger[input.requestId];
      if (replay) return { record, result: replay };
      if (record.sequence !== input.expectedSequence) {
        return { record, result: staleResponse(record, content.privateReel) };
      }
      assertMutable(record, this.now());

      const localized = localizedContent(content.privateReel, record.locale);
      const act = localized.acts[record.currentActIndex];
      const privateAct = content.privateReel.answers[record.locale as keyof typeof content.privateReel.answers];
      const correct = isCorrectAnswer(act.role, input.answer, privateAct);
      const currentProgress = record.acts[record.currentActIndex];
      const nextProgress = applyDailyReelActEvent(
        currentProgress,
        { type: correct ? "correct" : "incorrect" },
        record.config.maxIncorrectAttemptsPerAct,
      );
      const nextRecord = withProgress(record, nextProgress, this.now());
      const terminal = nextProgress.status !== "playing";
      const response: DailyReelMutationResponse = {
        disposition: "accepted",
        correct,
        actTerminal: terminal,
        reveal: terminal ? revealFor(act.role, privateAct) : null,
        assist: null,
        session: projectSession(nextRecord, content.privateReel),
      };
      return ledgerResult(nextRecord, input.requestId, response);
    });
  }

  async requestAssist(input: {
    capability: string;
    requestId: string;
    expectedSequence: number;
    assistId: string;
  }): Promise<DailyReelMutationResponse> {
    const existing = await this.requireSession(input.capability);
    const content = await this.requireVersion(existing.versionId);
    const capabilityHash = this.security.hashCapability(input.capability);
    return this.sessions.mutate(capabilityHash, (record) => {
      const replay = record.requestLedger[input.requestId];
      if (replay) return { record, result: replay };
      if (record.sequence !== input.expectedSequence) {
        return { record, result: staleResponse(record, content.privateReel) };
      }
      assertMutable(record, this.now());

      const localized = localizedContent(content.privateReel, record.locale);
      const act = localized.acts[record.currentActIndex];
      const option = act.assistOptions.find((candidate) => candidate.id === input.assistId);
      if (!option || !assistEnabled(record.config, option.kind)) {
        throw new DailyReelSessionError("assist.unavailable", "Requested assistance is unavailable");
      }
      const privateAct = content.privateReel.answers[record.locale as keyof typeof content.privateReel.answers];
      const currentProgress = record.acts[record.currentActIndex];
      const nextProgress = applyDailyReelActEvent(currentProgress, {
        type: "requestClue",
        clueId: option.id,
        affectsScore: option.scoreImpact === 1,
      });
      const changed = nextProgress !== currentProgress;
      const nextRecord = changed ? withNonTerminalProgress(record, nextProgress, this.now()) : record;
      const response: DailyReelMutationResponse = {
        disposition: "accepted",
        correct: null,
        actTerminal: false,
        reveal: null,
        assist: assistFor(act.role, option.id, option.kind, option.scoreImpact, privateAct),
        session: projectSession(nextRecord, content.privateReel),
      };
      return ledgerResult(nextRecord, input.requestId, response);
    });
  }

  async reveal(input: {
    capability: string;
    requestId: string;
    expectedSequence: number;
  }): Promise<DailyReelMutationResponse> {
    const existing = await this.requireSession(input.capability);
    const content = await this.requireVersion(existing.versionId);
    const capabilityHash = this.security.hashCapability(input.capability);
    return this.sessions.mutate(capabilityHash, (record) => {
      const replay = record.requestLedger[input.requestId];
      if (replay) return { record, result: replay };
      if (record.sequence !== input.expectedSequence) {
        return { record, result: staleResponse(record, content.privateReel) };
      }
      assertMutable(record, this.now());

      const localized = localizedContent(content.privateReel, record.locale);
      const act = localized.acts[record.currentActIndex];
      const privateAct = content.privateReel.answers[record.locale as keyof typeof content.privateReel.answers];
      const nextProgress = applyDailyReelActEvent(record.acts[record.currentActIndex], { type: "reveal" });
      const nextRecord = withProgress(record, nextProgress, this.now());
      const response: DailyReelMutationResponse = {
        disposition: "accepted",
        correct: false,
        actTerminal: true,
        reveal: revealFor(act.role, privateAct),
        assist: null,
        session: projectSession(nextRecord, content.privateReel),
      };
      return ledgerResult(nextRecord, input.requestId, response);
    });
  }

  private async requireSession(capability: string): Promise<DailyReelSessionRecord> {
    const capabilityHash = this.security.hashCapability(capability);
    const session = await this.sessions.get(capabilityHash);
    if (!session) throw new DailyReelSessionError("session.not_found", "Session was not found");
    return session;
  }

  private async requireVersion(versionId: string): Promise<DailyReelPublishedContent> {
    const content = await this.content.getVersion(versionId);
    if (!content) throw new DailyReelSessionError("content.unavailable", "Reel version was not found");
    return content;
  }
}

function withNonTerminalProgress(
  record: DailyReelSessionRecord,
  progress: DailyReelActProgress,
  now: Date,
): DailyReelSessionRecord {
  const acts = record.acts.map((act, index) =>
    index === record.currentActIndex ? { ...act, ...progress } : act,
  );
  return {
    ...record,
    sequence: record.sequence + 1,
    acts,
    updatedAt: now.toISOString(),
  };
}

function withProgress(
  record: DailyReelSessionRecord,
  progress: DailyReelActProgress,
  now: Date,
): DailyReelSessionRecord {
  const updated = withNonTerminalProgress(record, progress, now);
  if (progress.status === "playing") return updated;

  const nextActIndex = record.currentActIndex + 1;
  const completed = nextActIndex >= record.acts.length;
  return {
    ...updated,
    status: completed ? "completed" : "active",
    currentActIndex: nextActIndex,
    totalScore: totalDailyReelScore(updated.acts.map((act) => act.score ?? 0)),
    completedAt: completed ? now.toISOString() : null,
  };
}

function ledgerResult(
  record: DailyReelSessionRecord,
  requestIdInput: string,
  response: DailyReelMutationResponse,
): { record: DailyReelSessionRecord; result: DailyReelMutationResponse } {
  const requestId = requestIdInput.trim();
  if (!requestId) throw new DailyReelSessionError("request.invalid", "Request ID is required");
  const requestOrder = [...record.requestOrder.filter((value) => value !== requestId), requestId].slice(-24);
  const requestLedger = Object.fromEntries(
    requestOrder.map((value) => [value, value === requestId ? response : record.requestLedger[value]]),
  );
  return {
    record: { ...record, requestLedger, requestOrder },
    result: response,
  };
}

function staleResponse(record: DailyReelSessionRecord, reel: DailyReelPrivate): DailyReelMutationResponse {
  return {
    disposition: "stale",
    correct: null,
    actTerminal: false,
    reveal: null,
    assist: null,
    session: projectSession(record, reel),
  };
}

function projectSession(record: DailyReelSessionRecord, reel: DailyReelPrivate): DailyReelSessionProjection {
  const localized = localizedContent(reel, record.locale);
  return {
    contractVersion: "daily-reel-session.v1",
    sessionId: record.sessionId,
    publicationId: record.publicationId,
    contentVersion: record.versionId,
    scoringVersion: "daily-reel-score.v1",
    configId: record.config.configId,
    assignmentSource: record.assignmentSource,
    locale: record.locale,
    mode: record.mode,
    status: record.status,
    sequence: record.sequence,
    currentActIndex: record.currentActIndex,
    theme: localized.theme,
    currentAct: record.status === "active" ? localized.acts[record.currentActIndex] : null,
    acts: record.acts,
    totalScore: record.totalScore,
    completedAt: record.completedAt,
  };
}

function localizedContent(reel: DailyReelPrivate, locale: string) {
  return reel.reel.localized[locale as keyof typeof reel.reel.localized] ?? reel.reel.localized.en;
}

function isCorrectAnswer(
  role: DailyReelActRole,
  answer: unknown,
  privateActs: DailyReelPrivate["answers"]["en"],
): boolean {
  switch (role) {
  case "decode":
    return typeof answer === "string" && privateActs.decode.acceptedAnswers
      .some((candidate) => normalizeAnswer(candidate) === normalizeAnswer(answer));
  case "connect":
    return typeof answer === "string" && answer === privateActs.connect.correctChoiceId;
  case "arrange":
    return Array.isArray(answer)
      && answer.every((value) => typeof value === "string")
      && sameSequence(answer as string[], privateActs.arrange.correctOrder);
  }
}

function revealFor(
  role: DailyReelActRole,
  privateActs: DailyReelPrivate["answers"]["en"],
): DailyReelReveal {
  switch (role) {
  case "decode":
    return {
      role,
      title: privateActs.decode.revealTitle,
      explanation: privateActs.decode.explanation,
    };
  case "connect":
    return {
      role,
      correctChoiceId: privateActs.connect.correctChoiceId,
      explanation: privateActs.connect.explanation,
    };
  case "arrange": {
    const threadReveal = privateActs.threadReveal;
    return {
      role,
      correctOrder: [...privateActs.arrange.correctOrder],
      explanation: threadReveal
        ? `${privateActs.arrange.explanation} ${threadReveal.explanation}`
        : privateActs.arrange.explanation,
      ...(threadReveal ? {
        title: threadReveal.title,
        threadTitle: threadReveal.title,
        threadExplanation: threadReveal.explanation,
      } : {}),
    };
  }
  }
}

function assistFor(
  role: DailyReelActRole,
  id: string,
  kind: "titleLength" | "hint",
  scoreImpact: 0 | 1,
  privateActs: DailyReelPrivate["answers"]["en"],
): DailyReelAssistReveal {
  if (kind === "titleLength" && role === "decode") {
    return { id, kind, scoreImpact, titleLength: privateActs.decode.titleLength };
  }
  const text = role === "decode"
    ? privateActs.decode.hint
    : role === "connect"
      ? privateActs.connect.hint
      : privateActs.arrange.hint;
  return { id, kind, scoreImpact, text };
}

function assistEnabled(config: DailyReelExperienceConfig, kind: "titleLength" | "hint"): boolean {
  return kind === "titleLength"
    ? config.assistance.titleLength.enabled
    : config.assistance.standardHint.enabled;
}

function assertMutable(record: DailyReelSessionRecord, now: Date): void {
  assertNotExpired(record, now);
  if (record.status !== "active") {
    throw new DailyReelSessionError("session.completed", "Session is already complete");
  }
}

function assertNotExpired(record: DailyReelSessionRecord, now: Date): void {
  if (Date.parse(record.expiresAt) <= now.getTime()) {
    throw new DailyReelSessionError("session.expired", "Session has expired");
  }
}

function normalizeAnswer(value: string): string {
  return value
    .normalize("NFKD")
    .replace(/\p{M}/gu, "")
    .toLocaleLowerCase()
    .replace(/[^\p{L}\p{N}]+/gu, "")
    .trim();
}

function sameSequence(left: readonly string[], right: readonly string[]): boolean {
  return left.length === right.length && left.every((value, index) => value === right[index]);
}

function clone<T>(value: T): T {
  return value === null || value === undefined
    ? value
    : (JSON.parse(JSON.stringify(value)) as T);
}
