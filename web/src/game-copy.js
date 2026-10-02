export function connectionSceneCopy(act, previousTitle = null) {
  const films = Array.isArray(act?.films) ? act.films : [];
  if (films.length >= 2) {
    return {
      transition: "Act 1 complete. Compare these three different movies.",
      question: "What links these three movies?",
    };
  }
  const title = typeof previousTitle === "string" && previousTitle.trim() ? previousTitle.trim() : "this movie";
  return {
    transition: `Act 1 complete. Stay with ${title} for one quick detail.`,
    question: act?.prompt || "Which detail completes this scene?",
  };
}

export function appStoreResultCopy() {
  return {
    kicker: "Daily puzzles, watchlist & release alerts",
    action: "Keep movie night going in Streaming Now →",
  };
}

export function resultShareText({
  publicationId,
  marks,
  score,
  ticketTitle,
  festivalCount,
  festivalTarget,
  streak = 0,
  recoveryPreview = false,
  rivalHeadline = null,
}) {
  const lines = [
    `Daily Reel ${publicationId}`,
    `${marks} ${Number(score || 0).toLocaleString()} points`,
  ];
  if (rivalHeadline) lines.push(`🏆 ${rivalHeadline}`);
  lines.push(recoveryPreview
    ? `🎟 ${ticketTitle} · Warm-up collectible`
    : `🎟 ${ticketTitle} · Festival ${festivalCount}/${festivalTarget}${streak ? ` · ${streak} day streak` : ""}`);
  lines.push("Decode. Connect. Arrange.");
  return lines.join("\n");
}
