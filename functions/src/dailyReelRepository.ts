import type { Firestore } from "firebase-admin/firestore";
import type { DailyReelCandidate } from "./dailyReelGenerator.js";
import type { DailyReelQualityReport } from "./dailyReelQuality.js";

export const DAILY_REEL_COLLECTIONS = {
  candidates: "dailyReelCandidates",
  versions: "dailyReelVersions",
  schedule: "dailyReelSchedule",
  replacements: "dailyReelReplacementRequests",
  audit: "dailyReelAudit",
} as const;

const COLLECTIONS = DAILY_REEL_COLLECTIONS;

export interface DailyReelVersionRecord {
  versionId: string;
  candidateId: string;
  createdAt: string;
  privateReel: DailyReelCandidate["privateReel"];
}

export interface DailyReelScheduleRecord {
  publicationId: string;
  versionId: string;
  candidateId: string;
  scheduledAt: string;
  scheduledBy: string;
}

export interface DailyReelReplacementRequest {
  requestId: string;
  candidateId: string;
  publicationId: string;
  reasonCode: "qualityRejected" | "editorDenied";
  createdAt: string;
}

export interface DailyReelRepository {
  getCandidate(candidateId: string): Promise<DailyReelCandidate | null>;
  createCandidate(candidate: DailyReelCandidate): Promise<DailyReelCandidate>;
  recordValidation(candidateId: string, report: DailyReelQualityReport): Promise<DailyReelCandidate>;
  queueReplacement(
    candidateId: string,
    reasonCode: DailyReelReplacementRequest["reasonCode"],
  ): Promise<DailyReelReplacementRequest>;
  approveAndSchedule(
    candidateId: string,
    publicationId: string,
    actorId: string,
  ): Promise<DailyReelScheduleRecord>;
  denyAndQueueReplacement(candidateId: string, actorId: string): Promise<DailyReelReplacementRequest>;
}

export class DailyReelRepositoryConflictError extends Error {}
export class DailyReelRepositoryNotFoundError extends Error {}
export class DailyReelRepositoryTransitionError extends Error {}

export class InMemoryDailyReelRepository implements DailyReelRepository {
  private readonly candidates = new Map<string, DailyReelCandidate>();
  private readonly versions = new Map<string, DailyReelVersionRecord>();
  private readonly schedules = new Map<string, DailyReelScheduleRecord>();
  private readonly replacements = new Map<string, DailyReelReplacementRequest>();

  constructor(private readonly now: () => Date = () => new Date()) {}

  async getCandidate(candidateId: string): Promise<DailyReelCandidate | null> {
    return clone(this.candidates.get(candidateId) ?? null);
  }

  async createCandidate(candidate: DailyReelCandidate): Promise<DailyReelCandidate> {
    const existing = this.candidates.get(candidate.candidateId);
    if (existing) {
      if (existing.generationKey !== candidate.generationKey) {
        throw new DailyReelRepositoryConflictError("Candidate ID already belongs to another generation");
      }
      return clone(existing);
    }
    this.candidates.set(candidate.candidateId, clone(candidate));
    return clone(candidate);
  }

  async recordValidation(
    candidateId: string,
    report: DailyReelQualityReport,
  ): Promise<DailyReelCandidate> {
    const candidate = this.requireCandidate(candidateId);
    if (["awaitingApproval", "rejected"].includes(candidate.state)) {
      return clone(candidate);
    }
    if (!['generated', 'validating'].includes(candidate.state)) {
      throw new DailyReelRepositoryTransitionError(`Cannot validate candidate in ${candidate.state}`);
    }
    const updated: DailyReelCandidate = {
      ...candidate,
      state: report.passed ? "awaitingApproval" : "rejected",
      qualityReport: report,
      updatedAt: this.now().toISOString(),
    };
    this.candidates.set(candidateId, clone(updated));
    return clone(updated);
  }

  async queueReplacement(
    candidateId: string,
    reasonCode: DailyReelReplacementRequest["reasonCode"],
  ): Promise<DailyReelReplacementRequest> {
    const candidate = this.requireCandidate(candidateId);
    const requestId = replacementID(candidateId);
    const existing = this.replacements.get(requestId);
    if (existing) return clone(existing);

    const request: DailyReelReplacementRequest = {
      requestId,
      candidateId,
      publicationId: candidate.intendedPublicationId,
      reasonCode,
      createdAt: this.now().toISOString(),
    };
    this.replacements.set(requestId, clone(request));
    this.candidates.set(candidateId, { ...candidate, replacementQueued: true });
    return clone(request);
  }

  async approveAndSchedule(
    candidateId: string,
    publicationId: string,
    actorId: string,
  ): Promise<DailyReelScheduleRecord> {
    const candidate = this.requireCandidate(candidateId);
    const existingSchedule = this.schedules.get(publicationId);
    if (candidate.state === "scheduled" && existingSchedule?.candidateId === candidateId) {
      return clone(existingSchedule);
    }
    if (candidate.state !== "awaitingApproval") {
      throw new DailyReelRepositoryTransitionError(`Cannot approve candidate in ${candidate.state}`);
    }
    if (publicationId !== candidate.intendedPublicationId) {
      throw new DailyReelRepositoryConflictError("Candidate cannot be scheduled for a different publication");
    }
    if (existingSchedule) {
      throw new DailyReelRepositoryConflictError("Publication date is already scheduled");
    }

    const timestamp = this.now().toISOString();
    const versionId = candidate.privateReel.reel.contentVersion;
    const version: DailyReelVersionRecord = {
      versionId,
      candidateId,
      createdAt: timestamp,
      privateReel: candidate.privateReel,
    };
    const existingVersion = this.versions.get(versionId);
    if (existingVersion && existingVersion.candidateId !== candidateId) {
      throw new DailyReelRepositoryConflictError("Content version already belongs to another candidate");
    }

    const schedule: DailyReelScheduleRecord = {
      publicationId,
      versionId,
      candidateId,
      scheduledAt: timestamp,
      scheduledBy: actorId,
    };
    this.versions.set(versionId, clone(version));
    this.schedules.set(publicationId, clone(schedule));
    this.candidates.set(candidateId, {
      ...candidate,
      state: "scheduled",
      approvedVersionId: versionId,
      approvedAt: timestamp,
      approvedBy: actorId,
      updatedAt: timestamp,
    });
    return clone(schedule);
  }

  async denyAndQueueReplacement(
    candidateId: string,
    actorId: string,
  ): Promise<DailyReelReplacementRequest> {
    const candidate = this.requireCandidate(candidateId);
    if (candidate.state !== "awaitingApproval" && candidate.state !== "denied") {
      throw new DailyReelRepositoryTransitionError(`Cannot deny candidate in ${candidate.state}`);
    }
    if (candidate.state !== "denied") {
      const timestamp = this.now().toISOString();
      this.candidates.set(candidateId, {
        ...candidate,
        state: "denied",
        deniedAt: timestamp,
        deniedBy: actorId,
        updatedAt: timestamp,
      });
    }
    return this.queueReplacement(candidateId, "editorDenied");
  }

  private requireCandidate(candidateId: string): DailyReelCandidate {
    const candidate = this.candidates.get(candidateId);
    if (!candidate) {
      throw new DailyReelRepositoryNotFoundError(`Candidate ${candidateId} was not found`);
    }
    return candidate;
  }
}

export class FirestoreDailyReelRepository implements DailyReelRepository {
  constructor(
    private readonly db: Firestore,
    private readonly now: () => Date = () => new Date(),
  ) {}

  async getCandidate(candidateId: string): Promise<DailyReelCandidate | null> {
    const snapshot = await this.db.collection(COLLECTIONS.candidates).doc(candidateId).get();
    return snapshot.exists ? (snapshot.data() as DailyReelCandidate) : null;
  }

  async createCandidate(candidate: DailyReelCandidate): Promise<DailyReelCandidate> {
    const reference = this.db.collection(COLLECTIONS.candidates).doc(candidate.candidateId);
    return this.db.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(reference);
      if (snapshot.exists) {
        const existing = snapshot.data() as DailyReelCandidate;
        if (existing.generationKey !== candidate.generationKey) {
          throw new DailyReelRepositoryConflictError("Candidate ID already belongs to another generation");
        }
        return existing;
      }
      transaction.create(reference, candidate);
      return candidate;
    });
  }

  async recordValidation(
    candidateId: string,
    report: DailyReelQualityReport,
  ): Promise<DailyReelCandidate> {
    const reference = this.db.collection(COLLECTIONS.candidates).doc(candidateId);
    return this.db.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(reference);
      if (!snapshot.exists) throw new DailyReelRepositoryNotFoundError("Candidate was not found");
      const candidate = snapshot.data() as DailyReelCandidate;
      if (["awaitingApproval", "rejected"].includes(candidate.state)) return candidate;
      if (!["generated", "validating"].includes(candidate.state)) {
        throw new DailyReelRepositoryTransitionError(`Cannot validate candidate in ${candidate.state}`);
      }
      const updated: DailyReelCandidate = {
        ...candidate,
        state: report.passed ? "awaitingApproval" : "rejected",
        qualityReport: report,
        updatedAt: this.now().toISOString(),
      };
      transaction.set(reference, updated);
      return updated;
    });
  }

  async queueReplacement(
    candidateId: string,
    reasonCode: DailyReelReplacementRequest["reasonCode"],
  ): Promise<DailyReelReplacementRequest> {
    const candidateReference = this.db.collection(COLLECTIONS.candidates).doc(candidateId);
    const requestReference = this.db.collection(COLLECTIONS.replacements).doc(replacementID(candidateId));
    return this.db.runTransaction(async (transaction) => {
      const [candidateSnapshot, requestSnapshot] = await Promise.all([
        transaction.get(candidateReference),
        transaction.get(requestReference),
      ]);
      if (!candidateSnapshot.exists) throw new DailyReelRepositoryNotFoundError("Candidate was not found");
      if (requestSnapshot.exists) return requestSnapshot.data() as DailyReelReplacementRequest;
      const candidate = candidateSnapshot.data() as DailyReelCandidate;
      const request: DailyReelReplacementRequest = {
        requestId: replacementID(candidateId),
        candidateId,
        publicationId: candidate.intendedPublicationId,
        reasonCode,
        createdAt: this.now().toISOString(),
      };
      transaction.create(requestReference, request);
      transaction.update(candidateReference, { replacementQueued: true });
      return request;
    });
  }

  async approveAndSchedule(
    candidateId: string,
    publicationId: string,
    actorId: string,
  ): Promise<DailyReelScheduleRecord> {
    const candidateReference = this.db.collection(COLLECTIONS.candidates).doc(candidateId);
    const scheduleReference = this.db.collection(COLLECTIONS.schedule).doc(publicationId);
    return this.db.runTransaction(async (transaction) => {
      const [candidateSnapshot, scheduleSnapshot] = await Promise.all([
        transaction.get(candidateReference),
        transaction.get(scheduleReference),
      ]);
      if (!candidateSnapshot.exists) throw new DailyReelRepositoryNotFoundError("Candidate was not found");
      const candidate = candidateSnapshot.data() as DailyReelCandidate;
      if (candidate.state === "scheduled" && scheduleSnapshot.exists) {
        const existing = scheduleSnapshot.data() as DailyReelScheduleRecord;
        if (existing.candidateId === candidateId) return existing;
      }
      if (candidate.state !== "awaitingApproval") {
        throw new DailyReelRepositoryTransitionError(`Cannot approve candidate in ${candidate.state}`);
      }
      if (publicationId !== candidate.intendedPublicationId || scheduleSnapshot.exists) {
        throw new DailyReelRepositoryConflictError("Publication date is unavailable");
      }

      const timestamp = this.now().toISOString();
      const versionId = candidate.privateReel.reel.contentVersion;
      const versionReference = this.db.collection(COLLECTIONS.versions).doc(versionId);
      const versionSnapshot = await transaction.get(versionReference);
      if (versionSnapshot.exists) {
        const existing = versionSnapshot.data() as DailyReelVersionRecord;
        if (existing.candidateId !== candidateId) {
          throw new DailyReelRepositoryConflictError("Content version is already assigned");
        }
      } else {
        transaction.create(versionReference, {
          versionId,
          candidateId,
          createdAt: timestamp,
          privateReel: candidate.privateReel,
        } satisfies DailyReelVersionRecord);
      }

      const schedule: DailyReelScheduleRecord = {
        publicationId,
        versionId,
        candidateId,
        scheduledAt: timestamp,
        scheduledBy: actorId,
      };
      transaction.create(scheduleReference, schedule);
      transaction.update(candidateReference, {
        state: "scheduled",
        approvedVersionId: versionId,
        approvedAt: timestamp,
        approvedBy: actorId,
        updatedAt: timestamp,
      });
      transaction.create(this.db.collection(COLLECTIONS.audit).doc(`${candidateId}-approved`), {
        action: "approved",
        candidateId,
        publicationId,
        versionId,
        actorId,
        createdAt: timestamp,
      });
      return schedule;
    });
  }

  async denyAndQueueReplacement(
    candidateId: string,
    actorId: string,
  ): Promise<DailyReelReplacementRequest> {
    const candidateReference = this.db.collection(COLLECTIONS.candidates).doc(candidateId);
    const requestReference = this.db.collection(COLLECTIONS.replacements).doc(replacementID(candidateId));
    return this.db.runTransaction(async (transaction) => {
      const [candidateSnapshot, requestSnapshot] = await Promise.all([
        transaction.get(candidateReference),
        transaction.get(requestReference),
      ]);
      if (!candidateSnapshot.exists) throw new DailyReelRepositoryNotFoundError("Candidate was not found");
      const candidate = candidateSnapshot.data() as DailyReelCandidate;
      if (candidate.state !== "awaitingApproval" && candidate.state !== "denied") {
        throw new DailyReelRepositoryTransitionError(`Cannot deny candidate in ${candidate.state}`);
      }
      if (requestSnapshot.exists) return requestSnapshot.data() as DailyReelReplacementRequest;

      const timestamp = this.now().toISOString();
      const request: DailyReelReplacementRequest = {
        requestId: replacementID(candidateId),
        candidateId,
        publicationId: candidate.intendedPublicationId,
        reasonCode: "editorDenied",
        createdAt: timestamp,
      };
      transaction.update(candidateReference, {
        state: "denied",
        deniedAt: timestamp,
        deniedBy: actorId,
        updatedAt: timestamp,
        replacementQueued: true,
      });
      transaction.create(requestReference, request);
      transaction.create(this.db.collection(COLLECTIONS.audit).doc(`${candidateId}-denied`), {
        action: "denied",
        candidateId,
        publicationId: candidate.intendedPublicationId,
        actorId,
        createdAt: timestamp,
      });
      return request;
    });
  }
}

function replacementID(candidateId: string): string {
  return `${candidateId}-replacement`;
}

function clone<T>(value: T): T {
  return value === null || value === undefined
    ? value
    : (JSON.parse(JSON.stringify(value)) as T);
}
