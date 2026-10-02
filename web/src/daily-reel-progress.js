const STORAGE_KEY = "dailyReel.webProgress.v1";
const FESTIVAL_TARGET = 5;
const FESTIVAL_WINDOW_DAYS = 7;
const MAX_COMPLETIONS = 45;

export function createDailyReelProgressStore({ storage = browserStorage(), now = () => new Date() } = {}) {
  let record = readRecord(storage);

  return {
    snapshot(publicationId) {
      return summarize(record, publicationId);
    },

    recordCompletion(session) {
      if (session?.mode !== "daily" || !isPublicationId(session?.publicationId)) {
        return { ...summarize(record, session?.publicationId), changed: false, badgeAwarded: false };
      }

      const publicationId = session.publicationId;
      const changed = !record.completions[publicationId];
      record.completions[publicationId] = {
        completedAt: now().toISOString(),
        score: Math.max(0, Number(session.totalScore || 0)),
      };
      record.completions = Object.fromEntries(
        Object.entries(record.completions)
          .filter(([id]) => isPublicationId(id))
          .sort(([left], [right]) => right.localeCompare(left))
          .slice(0, MAX_COMPLETIONS),
      );

      const summary = summarize(record, publicationId);
      const badgeAwarded = summary.festivalComplete && !record.festivalBadgeAwardedAt;
      if (badgeAwarded) record.festivalBadgeAwardedAt = now().toISOString();
      writeRecord(storage, record);
      return { ...summary, changed, badgeAwarded };
    },
  };
}

export function nextReelCountdown(date = new Date()) {
  const next = new Date(Date.UTC(
    date.getUTCFullYear(),
    date.getUTCMonth(),
    date.getUTCDate(),
    5,
  ));
  if (next <= date) next.setUTCDate(next.getUTCDate() + 1);
  const minutes = Math.max(0, Math.ceil((next.getTime() - date.getTime()) / 60_000));
  const hours = Math.floor(minutes / 60);
  return `${hours}h ${String(minutes % 60).padStart(2, "0")}m`;
}

function summarize(record, publicationId) {
  const ids = Object.keys(record.completions).filter(isPublicationId).sort();
  const completedToday = ids.includes(publicationId);
  const windowStart = shiftPublicationId(publicationId, -(FESTIVAL_WINDOW_DAYS - 1));
  const festivalCount = ids.filter((id) => id >= windowStart && id <= publicationId).length;
  const streakAnchor = completedToday ? publicationId : shiftPublicationId(publicationId, -1);
  const completed = new Set(ids);
  let streak = 0;
  let cursor = streakAnchor;
  while (completed.has(cursor)) {
    streak += 1;
    cursor = shiftPublicationId(cursor, -1);
  }
  return {
    completedToday,
    festivalCount: Math.min(FESTIVAL_TARGET, festivalCount),
    festivalTarget: FESTIVAL_TARGET,
    festivalComplete: festivalCount >= FESTIVAL_TARGET,
    streak,
    totalCompleted: ids.length,
  };
}

function shiftPublicationId(publicationId, days) {
  if (!isPublicationId(publicationId)) return "0000-00-00";
  const date = new Date(`${publicationId}T12:00:00Z`);
  date.setUTCDate(date.getUTCDate() + days);
  return date.toISOString().slice(0, 10);
}

function isPublicationId(value) {
  return /^\d{4}-\d{2}-\d{2}$/.test(String(value || ""));
}

function browserStorage() {
  try {
    return globalThis.localStorage;
  } catch {
    return null;
  }
}

function readRecord(storage) {
  try {
    const value = JSON.parse(storage?.getItem(STORAGE_KEY) || "null");
    if (value && typeof value === "object" && value.completions && typeof value.completions === "object") {
      return value;
    }
  } catch {
    // Progress is an enhancement; private browsing must not block the game.
  }
  return { completions: {}, festivalBadgeAwardedAt: null };
}

function writeRecord(storage, value) {
  try {
    storage?.setItem(STORAGE_KEY, JSON.stringify(value));
  } catch {
    // Keep the current run playable when storage is unavailable or full.
  }
}
