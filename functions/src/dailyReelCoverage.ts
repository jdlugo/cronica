import type { DocumentReference, Firestore } from "firebase-admin/firestore";
import type { DailyReelCandidate } from "./dailyReelGenerator.js";
import {
  DAILY_REEL_COLLECTIONS,
  type DailyReelScheduleRecord,
  type DailyReelVersionRecord,
} from "./dailyReelRepository.js";

const COVERAGE_COLLECTIONS = {
  evergreen: "dailyReelEvergreen",
  publications: "dailyReelPublications",
  operations: "dailyReelOperations",
} as const;

export interface DailyReelQueueHealth {
  evaluatedAt: string;
  firstPublicationId: string;
  targetDays: number;
  warningThreshold: number;
  approvedDays: number;
  missingPublicationIds: string[];
  warningEmitted: boolean;
}

export interface DailyReelEvergreenRecord {
  evergreenId: string;
  versionId: string;
  candidateId: string;
  approvedAt: string;
  approvedBy: string;
  eligible: boolean;
  priority: number;
  cooldownDays: number;
  lastUsedPublicationId: string | null;
  lastUsedAt: string | null;
}

export interface DailyReelPublicationRecord {
  publicationId: string;
  versionId: string;
  candidateId: string;
  source: "scheduled" | "evergreen";
  publishedAt: string;
}

export interface DailyReelCoverageStore {
  getSchedules(publicationIds: readonly string[]): Promise<Map<string, DailyReelScheduleRecord>>;
  recordQueueWarningOnce(warningId: string, health: Omit<DailyReelQueueHealth, "warningEmitted">): Promise<boolean>;
  listEligibleEvergreen(): Promise<DailyReelEvergreenRecord[]>;
  publishAtomic(input: {
    publicationId: string;
    preferredEvergreenId: string | null;
    publishedAt: string;
  }): Promise<DailyReelPublicationRecord>;
}

export class DailyReelNoApprovedPublicationError extends Error {}

export class DailyReelCoverageService {
  constructor(
    private readonly store: DailyReelCoverageStore,
    private readonly now: () => Date = () => new Date(),
  ) {}

  async evaluateQueue(input: {
    firstPublicationId: string;
    targetDays?: number;
    warningThreshold?: number;
  }): Promise<DailyReelQueueHealth> {
    const targetDays = clampPositive(input.targetDays ?? 14);
    const warningThreshold = clampPositive(input.warningThreshold ?? 7);
    const firstPublicationId = requirePublicationId(input.firstPublicationId);
    const publicationIds = publicationRange(firstPublicationId, targetDays);
    const schedules = await this.store.getSchedules(publicationIds);
    const missingPublicationIds = publicationIds.filter((publicationId) => !schedules.has(publicationId));
    const evaluatedAt = this.now().toISOString();
    const healthWithoutWarning: Omit<DailyReelQueueHealth, "warningEmitted"> = {
      evaluatedAt,
      firstPublicationId,
      targetDays,
      warningThreshold,
      approvedDays: targetDays - missingPublicationIds.length,
      missingPublicationIds,
    };

    let warningEmitted = false;
    if (healthWithoutWarning.approvedDays < warningThreshold) {
      const warningDay = evaluatedAt.slice(0, 10);
      warningEmitted = await this.store.recordQueueWarningOnce(
        `daily-reel-queue-below-${warningThreshold}-${warningDay}`,
        healthWithoutWarning,
      );
    }
    return { ...healthWithoutWarning, warningEmitted };
  }

  async publish(publicationIdInput: string): Promise<DailyReelPublicationRecord> {
    const publicationId = requirePublicationId(publicationIdInput);
    const publishedAt = this.now().toISOString();
    const schedules = await this.store.getSchedules([publicationId]);
    let preferredEvergreenId: string | null = null;

    if (!schedules.has(publicationId)) {
      const evergreen = (await this.store.listEligibleEvergreen())
        .filter((record) => isOutsideCooldown(record, publishedAt))
        .sort(compareEvergreen)[0];
      if (!evergreen) {
        throw new DailyReelNoApprovedPublicationError(
          `No scheduled or eligible approved evergreen Reel exists for ${publicationId}`,
        );
      }
      preferredEvergreenId = evergreen.evergreenId;
    }

    return this.store.publishAtomic({ publicationId, preferredEvergreenId, publishedAt });
  }
}

export class InMemoryDailyReelCoverageStore implements DailyReelCoverageStore {
  readonly schedules = new Map<string, DailyReelScheduleRecord>();
  readonly versions = new Map<string, DailyReelVersionRecord>();
  readonly candidates = new Map<string, DailyReelCandidate>();
  readonly evergreen = new Map<string, DailyReelEvergreenRecord>();
  readonly publications = new Map<string, DailyReelPublicationRecord>();
  readonly warnings = new Set<string>();

  async getSchedules(publicationIds: readonly string[]): Promise<Map<string, DailyReelScheduleRecord>> {
    return new Map(
      publicationIds.flatMap((publicationId) => {
        const schedule = this.schedules.get(publicationId);
        return schedule ? [[publicationId, clone(schedule)] as const] : [];
      }),
    );
  }

  async recordQueueWarningOnce(
    warningId: string,
    _health: Omit<DailyReelQueueHealth, "warningEmitted">,
  ): Promise<boolean> {
    if (this.warnings.has(warningId)) return false;
    this.warnings.add(warningId);
    return true;
  }

  async listEligibleEvergreen(): Promise<DailyReelEvergreenRecord[]> {
    return [...this.evergreen.values()].filter((record) => record.eligible).map(clone);
  }

  async publishAtomic(input: {
    publicationId: string;
    preferredEvergreenId: string | null;
    publishedAt: string;
  }): Promise<DailyReelPublicationRecord> {
    const existing = this.publications.get(input.publicationId);
    if (existing) return clone(existing);

    const schedule = this.schedules.get(input.publicationId);
    let versionId: string;
    let candidateId: string;
    let source: DailyReelPublicationRecord["source"];
    let evergreenRecord: DailyReelEvergreenRecord | undefined;

    if (schedule) {
      versionId = schedule.versionId;
      candidateId = schedule.candidateId;
      source = "scheduled";
    } else {
      evergreenRecord = input.preferredEvergreenId
        ? this.evergreen.get(input.preferredEvergreenId)
        : undefined;
      if (!evergreenRecord || !evergreenRecord.eligible || !isOutsideCooldown(evergreenRecord, input.publishedAt)) {
        throw new DailyReelNoApprovedPublicationError("Selected evergreen Reel is unavailable");
      }
      versionId = evergreenRecord.versionId;
      candidateId = evergreenRecord.candidateId;
      source = "evergreen";
    }

    if (!this.versions.has(versionId)) {
      throw new DailyReelNoApprovedPublicationError("Approved version record is missing");
    }
    const publication: DailyReelPublicationRecord = {
      publicationId: input.publicationId,
      versionId,
      candidateId,
      source,
      publishedAt: input.publishedAt,
    };
    this.publications.set(input.publicationId, clone(publication));
    const candidate = this.candidates.get(candidateId);
    if (candidate) {
      this.candidates.set(candidateId, {
        ...candidate,
        state: "published",
        updatedAt: input.publishedAt,
      });
    }
    if (evergreenRecord) {
      this.evergreen.set(evergreenRecord.evergreenId, {
        ...evergreenRecord,
        lastUsedPublicationId: input.publicationId,
        lastUsedAt: input.publishedAt,
      });
    }
    return clone(publication);
  }
}

export class FirestoreDailyReelCoverageStore implements DailyReelCoverageStore {
  constructor(private readonly db: Firestore) {}

  async getSchedules(publicationIds: readonly string[]): Promise<Map<string, DailyReelScheduleRecord>> {
    if (publicationIds.length === 0) return new Map();
    const references = publicationIds.map((publicationId) =>
      this.db.collection(DAILY_REEL_COLLECTIONS.schedule).doc(publicationId),
    );
    const snapshots = await this.db.getAll(...references);
    return new Map(
      snapshots.flatMap((snapshot) =>
        snapshot.exists
          ? [[snapshot.id, snapshot.data() as DailyReelScheduleRecord] as const]
          : [],
      ),
    );
  }

  async recordQueueWarningOnce(
    warningId: string,
    health: Omit<DailyReelQueueHealth, "warningEmitted">,
  ): Promise<boolean> {
    const reference = this.db.collection(COVERAGE_COLLECTIONS.operations).doc(warningId);
    return this.db.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(reference);
      if (snapshot.exists) return false;
      transaction.create(reference, {
        type: "queueBelowThreshold",
        ...health,
      });
      return true;
    });
  }

  async listEligibleEvergreen(): Promise<DailyReelEvergreenRecord[]> {
    const snapshot = await this.db
      .collection(COVERAGE_COLLECTIONS.evergreen)
      .where("eligible", "==", true)
      .get();
    return snapshot.docs.map((document) => document.data() as DailyReelEvergreenRecord);
  }

  async publishAtomic(input: {
    publicationId: string;
    preferredEvergreenId: string | null;
    publishedAt: string;
  }): Promise<DailyReelPublicationRecord> {
    const publicationReference = this.db
      .collection(COVERAGE_COLLECTIONS.publications)
      .doc(input.publicationId);
    const scheduleReference = this.db
      .collection(DAILY_REEL_COLLECTIONS.schedule)
      .doc(input.publicationId);

    return this.db.runTransaction(async (transaction) => {
      const [publicationSnapshot, scheduleSnapshot] = await Promise.all([
        transaction.get(publicationReference),
        transaction.get(scheduleReference),
      ]);
      if (publicationSnapshot.exists) {
        return publicationSnapshot.data() as DailyReelPublicationRecord;
      }

      let versionId: string;
      let candidateId: string;
      let source: DailyReelPublicationRecord["source"];
      let evergreenReference: DocumentReference | null = null;

      if (scheduleSnapshot.exists) {
        const schedule = scheduleSnapshot.data() as DailyReelScheduleRecord;
        versionId = schedule.versionId;
        candidateId = schedule.candidateId;
        source = "scheduled";
      } else {
        if (!input.preferredEvergreenId) {
          throw new DailyReelNoApprovedPublicationError("No approved fallback was selected");
        }
        const reference = this.db
          .collection(COVERAGE_COLLECTIONS.evergreen)
          .doc(input.preferredEvergreenId);
        const snapshot = await transaction.get(reference);
        if (!snapshot.exists) throw new DailyReelNoApprovedPublicationError("Evergreen Reel was not found");
        const record = snapshot.data() as DailyReelEvergreenRecord;
        if (!record.eligible || !isOutsideCooldown(record, input.publishedAt)) {
          throw new DailyReelNoApprovedPublicationError("Evergreen Reel is ineligible or cooling down");
        }
        versionId = record.versionId;
        candidateId = record.candidateId;
        source = "evergreen";
        evergreenReference = reference;
      }

      const versionReference = this.db.collection(DAILY_REEL_COLLECTIONS.versions).doc(versionId);
      const versionSnapshot = await transaction.get(versionReference);
      if (!versionSnapshot.exists) {
        throw new DailyReelNoApprovedPublicationError("Approved version record is missing");
      }
      const candidateReference = this.db.collection(DAILY_REEL_COLLECTIONS.candidates).doc(candidateId);
      const candidateSnapshot = await transaction.get(candidateReference);

      const publication: DailyReelPublicationRecord = {
        publicationId: input.publicationId,
        versionId,
        candidateId,
        source,
        publishedAt: input.publishedAt,
      };
      transaction.create(publicationReference, publication);
      if (candidateSnapshot.exists) {
        transaction.update(candidateReference, {
          state: "published",
          updatedAt: input.publishedAt,
        });
      }
      transaction.create(
        this.db.collection(DAILY_REEL_COLLECTIONS.audit).doc(`${candidateId}-published-${input.publicationId}`),
        {
          action: "published",
          candidateId,
          publicationId: input.publicationId,
          versionId,
          source,
          createdAt: input.publishedAt,
        },
      );
      if (evergreenReference) {
        transaction.update(evergreenReference, {
          lastUsedPublicationId: input.publicationId,
          lastUsedAt: input.publishedAt,
        });
      }
      return publication;
    });
  }
}

function compareEvergreen(left: DailyReelEvergreenRecord, right: DailyReelEvergreenRecord): number {
  if (left.priority !== right.priority) return right.priority - left.priority;
  const leftUsed = left.lastUsedAt ?? "";
  const rightUsed = right.lastUsedAt ?? "";
  return leftUsed.localeCompare(rightUsed) || left.evergreenId.localeCompare(right.evergreenId);
}

function isOutsideCooldown(record: DailyReelEvergreenRecord, at: string): boolean {
  if (!record.lastUsedAt) return true;
  const elapsedMilliseconds = Date.parse(at) - Date.parse(record.lastUsedAt);
  return elapsedMilliseconds >= record.cooldownDays * 24 * 60 * 60 * 1000;
}

function publicationRange(firstPublicationId: string, count: number): string[] {
  const first = new Date(`${firstPublicationId}T00:00:00.000Z`);
  return Array.from({ length: count }, (_, offset) => {
    const date = new Date(first);
    date.setUTCDate(first.getUTCDate() + offset);
    return date.toISOString().slice(0, 10);
  });
}

function requirePublicationId(value: string): string {
  const publicationId = value.trim();
  if (!/^\d{4}-\d{2}-\d{2}$/.test(publicationId) || Number.isNaN(Date.parse(`${publicationId}T00:00:00Z`))) {
    throw new Error("Publication ID must be a valid YYYY-MM-DD date");
  }
  return publicationId;
}

function clampPositive(value: number): number {
  return Math.max(1, Math.trunc(value));
}

function clone<T>(value: T): T {
  return JSON.parse(JSON.stringify(value)) as T;
}
