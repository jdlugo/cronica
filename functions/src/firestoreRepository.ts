import type { Firestore } from "firebase-admin/firestore";

import type { DailyPuzzleDocument } from "./puzzleSchema.js";
import { buildLookbackDateStamps, extractRecentTmdbIDs, isAlreadyExistsError } from "./schedulerUtils.js";

const DAILY_PUZZLES_COLLECTION = "dailyPuzzles";

function dayStamp(date: Date): string {
  return date.toISOString().slice(0, 10);
}

export async function loadRecentPuzzleTmdbIDs(
  db: Firestore,
  targetDate: Date,
  collectionName = DAILY_PUZZLES_COLLECTION,
  lookbackDays = 30
): Promise<number[]> {
  const dates = buildLookbackDateStamps(targetDate, lookbackDays);
  const snapshots = await Promise.all(
    dates.map((date) => db.collection(collectionName).doc(date).get())
  );

  return extractRecentTmdbIDs(snapshots.map((snapshot) => snapshot.data() ?? {}));
}

export async function loadPuzzleByDate(
  db: Firestore,
  targetDate: Date,
  collectionName = DAILY_PUZZLES_COLLECTION
): Promise<Record<string, unknown> | null> {
  const snapshot = await db.collection(collectionName).doc(dayStamp(targetDate)).get();
  if (!snapshot.exists) {
    return null;
  }
  return snapshot.data() ?? null;
}

export async function loadRandomPuzzleDocument(
  db: Firestore,
  collectionName = DAILY_PUZZLES_COLLECTION,
  maxCandidates = 120,
  random: () => number = Math.random
): Promise<Record<string, unknown> | null> {
  const snapshot = await db
    .collection(collectionName)
    .where("practice_eligible", "==", true)
    .limit(maxCandidates)
    .get();

  const candidates = snapshot.docs
    .filter((doc) => doc.id !== "latest")
    .map((doc) => doc.data() ?? null)
    .filter((doc): doc is Record<string, unknown> => doc != null);

  if (candidates.length === 0) {
    return null;
  }

  const boundedRandom = Math.max(0, Math.min(0.999999, random()));
  const index = Math.floor(boundedRandom * candidates.length);
  return candidates[index] ?? null;
}

export async function persistPuzzleDocument(
  db: Firestore,
  puzzle: DailyPuzzleDocument,
  collectionName = DAILY_PUZZLES_COLLECTION
): Promise<boolean> {
  try {
    await db.collection(collectionName).doc(puzzle.date).create(puzzle);
  } catch (error) {
    if (isAlreadyExistsError(error)) {
      return false;
    }
    throw error;
  }

  await db
    .collection(collectionName)
    .doc("latest")
    .set({ ...puzzle, updated_at: puzzle.generated_at }, { merge: true });

  return true;
}
