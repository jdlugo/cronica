export function decorateChallengeURL(value, { score, cut }) {
  const url = new URL(value, globalThis.location?.origin || "https://streaming-now-daily-reel.web.app");
  const normalizedScore = Math.max(0, Math.round(Number(score) || 0));
  url.searchParams.set("rival_score", String(normalizedScore));
  if (typeof cut === "string" && cut.trim()) url.searchParams.set("rival_cut", cut.trim().slice(0, 48));
  return url.toString();
}

export function readRivalContext(value) {
  const params = value instanceof URLSearchParams ? value : new URLSearchParams(value || "");
  if (!params.has("rival_score")) return null;
  const score = Number(params.get("rival_score"));
  if (!Number.isFinite(score) || score < 0 || score > 100_000) return null;
  const cut = String(params.get("rival_cut") || "Final Cut").trim().slice(0, 48) || "Final Cut";
  return { score: Math.round(score), cut };
}

export function rivalResult(score, rival) {
  if (!rival) return null;
  const delta = Math.round((Number(score) || 0) - rival.score);
  if (delta > 0) return { outcome: "won", delta, title: `You beat the cut by ${delta.toLocaleString()}` };
  if (delta < 0) return { outcome: "lost", delta, title: `${Math.abs(delta).toLocaleString()} points to the comeback` };
  return { outcome: "tied", delta: 0, title: "A frame-perfect tie" };
}
