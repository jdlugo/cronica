import { describe, expect, it } from "vitest";
import {
  DailyReelCoverageService,
  DailyReelNoApprovedPublicationError,
  InMemoryDailyReelCoverageStore,
  type DailyReelEvergreenRecord,
} from "../dailyReelCoverage.js";
import type { DailyReelScheduleRecord, DailyReelVersionRecord } from "../dailyReelRepository.js";
import { makeCandidate, makePrivateReel } from "./dailyReelTestFixtures.js";

const now = () => new Date("2026-08-28T12:00:00Z");

function version(versionId = "fixture-2026-08-28.1"): DailyReelVersionRecord {
  return {
    versionId,
    candidateId: `candidate-${versionId}`,
    createdAt: "2026-08-20T12:00:00.000Z",
    privateReel: makePrivateReel(),
  };
}

function schedule(publicationId: string, record: DailyReelVersionRecord): DailyReelScheduleRecord {
  return {
    publicationId,
    versionId: record.versionId,
    candidateId: record.candidateId,
    scheduledAt: "2026-08-20T12:00:00.000Z",
    scheduledBy: "reviewer-hash",
  };
}

function evergreen(record: DailyReelVersionRecord): DailyReelEvergreenRecord {
  return {
    evergreenId: `evergreen-${record.versionId}`,
    versionId: record.versionId,
    candidateId: record.candidateId,
    approvedAt: "2026-08-20T12:00:00.000Z",
    approvedBy: "reviewer-hash",
    eligible: true,
    priority: 10,
    cooldownDays: 30,
    lastUsedPublicationId: null,
    lastUsedAt: null,
  };
}

describe("DailyReelCoverageService", () => {
  it("reports a fourteen-day queue and emits one warning per day below seven", async () => {
    const store = new InMemoryDailyReelCoverageStore();
    const record = version();
    store.versions.set(record.versionId, record);
    for (let day = 28; day <= 33; day += 1) {
      const date = new Date(Date.UTC(2026, 7, day)).toISOString().slice(0, 10);
      store.schedules.set(date, schedule(date, record));
    }
    const service = new DailyReelCoverageService(store, now);

    const first = await service.evaluateQueue({ firstPublicationId: "2026-08-28" });
    const second = await service.evaluateQueue({ firstPublicationId: "2026-08-28" });

    expect(first.targetDays).toBe(14);
    expect(first.approvedDays).toBe(6);
    expect(first.warningEmitted).toBe(true);
    expect(second.warningEmitted).toBe(false);
    expect(store.warnings).toHaveLength(1);
  });

  it("does not warn at seven approved future days", async () => {
    const store = new InMemoryDailyReelCoverageStore();
    const record = version();
    store.versions.set(record.versionId, record);
    for (let offset = 0; offset < 7; offset += 1) {
      const date = new Date(Date.UTC(2026, 7, 28 + offset)).toISOString().slice(0, 10);
      store.schedules.set(date, schedule(date, record));
    }

    const health = await new DailyReelCoverageService(store, now)
      .evaluateQueue({ firstPublicationId: "2026-08-28" });

    expect(health.approvedDays).toBe(7);
    expect(health.warningEmitted).toBe(false);
  });

  it("publishes an approved scheduled version idempotently", async () => {
    const store = new InMemoryDailyReelCoverageStore();
    const record = version();
    store.versions.set(record.versionId, record);
    store.candidates.set(record.candidateId, makeCandidate({
      candidateId: record.candidateId,
      state: "scheduled",
    }));
    store.schedules.set("2026-08-28", schedule("2026-08-28", record));
    const service = new DailyReelCoverageService(store, now);

    const first = await service.publish("2026-08-28");
    const second = await service.publish("2026-08-28");

    expect(first.source).toBe("scheduled");
    expect(second).toEqual(first);
    expect(store.publications).toHaveLength(1);
    expect(store.candidates.get(record.candidateId)?.state).toBe("published");
  });

  it("uses only an explicitly approved evergreen version for a missing date", async () => {
    const store = new InMemoryDailyReelCoverageStore();
    const record = version();
    store.versions.set(record.versionId, record);
    store.evergreen.set("evergreen-fixture", { ...evergreen(record), evergreenId: "evergreen-fixture" });

    const publication = await new DailyReelCoverageService(store, now).publish("2026-08-28");

    expect(publication.source).toBe("evergreen");
    expect(store.evergreen.get("evergreen-fixture")?.lastUsedPublicationId).toBe("2026-08-28");
  });

  it("refuses unapproved or cooling-down fallback content", async () => {
    const store = new InMemoryDailyReelCoverageStore();
    const record = version();
    store.versions.set(record.versionId, record);
    store.evergreen.set("cooling", {
      ...evergreen(record),
      evergreenId: "cooling",
      lastUsedPublicationId: "2026-08-20",
      lastUsedAt: "2026-08-20T12:00:00.000Z",
    });

    await expect(
      new DailyReelCoverageService(store, now).publish("2026-08-28"),
    ).rejects.toBeInstanceOf(DailyReelNoApprovedPublicationError);
  });
});
