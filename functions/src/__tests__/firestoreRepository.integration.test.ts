import { initializeApp, deleteApp, type App } from "firebase-admin/app";
import { getFirestore, type Firestore } from "firebase-admin/firestore";
import { afterAll, beforeAll, describe, expect, it } from "vitest";

import {
  loadPuzzleByDate,
  loadRandomPuzzleDocument,
  loadRecentPuzzleTmdbIDs,
  persistPuzzleDocument
} from "../firestoreRepository.js";
import type { DailyPuzzleDocument } from "../puzzleSchema.js";

const hasFirestoreEmulator = Boolean(process.env.FIRESTORE_EMULATOR_HOST);
const runDescribe = hasFirestoreEmulator ? describe : describe.skip;

function createCollectionName(): string {
  return `dailyPuzzles_test_${Date.now()}_${Math.random().toString(16).slice(2, 10)}`;
}

function makePuzzle(date: string, tmdbID: number): DailyPuzzleDocument {
  return {
    date,
    puzzle_id: date,
    media_type: "movie",
    tmdb_id: tmdbID,
    title: `Movie ${tmdbID}`,
    emoji_clue: "🎬⭐🔥",
    hint_1: "Hint 1",
    hint_2: "Hint 2",
    accepted_answers: [`movie ${tmdbID}`],
    source: "ai+tmdb",
    practice_eligible: true,
    generated_at: "2026-02-16T05:00:00.000Z"
  };
}

runDescribe("firestoreRepository integration", () => {
  let app: App;
  let db: Firestore;

  beforeAll(() => {
    if (!process.env.FIRESTORE_EMULATOR_HOST) {
      throw new Error("FIRESTORE_EMULATOR_HOST is required for integration tests");
    }
    app = initializeApp(
      { projectId: process.env.GCLOUD_PROJECT || "demo-daily-puzzle" },
      `firestore-repo-test-${Date.now()}`
    );
    db = getFirestore(app);
  });

  afterAll(async () => {
    await deleteApp(app);
  });

  it("persists puzzle once and prevents overwrite for same date", async () => {
    const collectionName = createCollectionName();
    const firstPuzzle = makePuzzle("2026-02-16", 597);
    const secondPuzzle = makePuzzle("2026-02-16", 27205);

    const firstPersisted = await persistPuzzleDocument(db, firstPuzzle, collectionName);
    const secondPersisted = await persistPuzzleDocument(db, secondPuzzle, collectionName);

    expect(firstPersisted).toBe(true);
    expect(secondPersisted).toBe(false);

    const persisted = await loadPuzzleByDate(db, new Date("2026-02-16T05:00:00.000Z"), collectionName);
    expect(persisted?.tmdb_id).toBe(597);

    const latestDoc = await db.collection(collectionName).doc("latest").get();
    expect(latestDoc.data()?.tmdb_id).toBe(597);
  });

  it("loads unique recent tmdb ids from lookback window", async () => {
    const collectionName = createCollectionName();
    await persistPuzzleDocument(db, makePuzzle("2026-02-15", 597), collectionName);
    await persistPuzzleDocument(db, makePuzzle("2026-02-14", 27205), collectionName);
    await persistPuzzleDocument(db, makePuzzle("2026-02-13", 597), collectionName);

    const ids = await loadRecentPuzzleTmdbIDs(
      db,
      new Date("2026-02-16T05:00:00.000Z"),
      collectionName,
      3
    );

    expect(ids).toEqual([597, 27205]);
  });

  it("loads a random puzzle from recent documents and excludes latest alias document", async () => {
    const collectionName = createCollectionName();
    await persistPuzzleDocument(db, makePuzzle("2026-02-13", 111), collectionName);
    await persistPuzzleDocument(db, makePuzzle("2026-02-14", 222), collectionName);
    await persistPuzzleDocument(db, makePuzzle("2026-02-15", 333), collectionName);

    const randomPuzzle = await loadRandomPuzzleDocument(db, collectionName, 120, () => 0.5);

    expect(randomPuzzle?.tmdb_id).toBe(222);
  });
});
