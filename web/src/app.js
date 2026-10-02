import { consumeChallengeCapability, createBrowserIdentity, createCapabilityStore, DailyReelClientError, LiveDailyReelClient } from "./daily-reel-client.js?v=6";
import { dailyReelPublicationId } from "./daily-reel-calendar.js?v=2";
import { completionThreadFor, DailyReelMachine } from "./daily-reel-machine.js?v=7";
import { createDailyReelProgressStore, nextReelCountdown } from "./daily-reel-progress.js?v=1";
import { DemoDailyReelClient } from "./demo-client.js?v=3";
import { createFirebaseAppCheckTokenProvider } from "./firebase-app-check.js?v=3";
import { dailyReelFirebaseConfig } from "./firebase-config.js?v=2";
import { isDailyReelRolloutEnabled, PostHogBridge } from "./posthog-bridge.js?v=8";
import { deliverShare } from "./share-delivery.js?v=1";
import { decorateChallengeURL, readRivalContext, rivalResult } from "./challenge-context.js?v=1";
import { appStoreResultCopy, connectionSceneCopy, resultShareText } from "./game-copy.js?v=2";
import { contentAttribution } from "./session-telemetry.js?v=1";

const config = globalThis.__DAILY_REEL_CONFIG__ || {};
const isPreview = config.mode === "preview";
const query = new URLSearchParams(location.search);
const isRecoveryPreview = isPreview && query.get("recovery") === "app-check";
const rivalContext = readRivalContext(query);
const challengeCapability = isPreview ? null : consumeChallengeCapability();
const requestedMode = query.get("mode") === "practice" ? "practice" : "daily";
const scopeId = requestedMode === "practice" ? query.get("scope") || crypto.randomUUID() : null;
const appStoreURL = config.appStoreURL || "https://apps.apple.com/app/id455556959";
const identity = createBrowserIdentity();
const distinctId = await identity.get();
const posthog = new PostHogBridge({
  projectToken: config.posthogProjectToken,
  host: config.posthogHost,
  distinctId,
});
let rolloutValue = isPreview ? "preview" : "pending";
const rolloutVariant = isPreview
  ? Promise.resolve("preview")
  : Promise.race([
    posthog.featureFlag("daily-reel-rollout"),
    new Promise((resolve) => setTimeout(() => resolve("pending"), 2000)),
  ]).then((value) => {
    rolloutValue = value;
    return value;
  });
const rolloutEnabled = isPreview || config.publicLaunch === true
  ? true
  : isDailyReelRolloutEnabled(await rolloutVariant, config.publicLaunch === true);
const disabledClient = {
  async start() {
    throw new DailyReelClientError("experience.ineligible", "Daily Reel is not enabled", 403);
  },
};
const liveClient = isPreview ? null : new LiveDailyReelClient({
  baseUrl: config.apiBaseUrl,
  identity,
  appCheckToken: createFirebaseAppCheckTokenProvider({
    firebaseConfig: config.firebaseConfig || dailyReelFirebaseConfig,
    recaptchaEnterpriseSiteKey: config.recaptchaEnterpriseSiteKey,
    enableDebug: config.enableAppCheckDebug === true,
  }),
});
const client = isPreview
  ? new DemoDailyReelClient()
  : challengeCapability || rolloutEnabled ? liveClient : disabledClient;
const machine = new DailyReelMachine({
  client,
  capabilities: createCapabilityStore(),
  publicationId: config.publicationId || dailyReelPublicationId(),
  locale: config.locale || navigator.language || "en",
  mode: requestedMode,
  scopeId,
  track: (event, properties) => posthog.capture(event, {
    ...properties,
    rollout_variant: String(rolloutValue || "disabled"),
  }),
});

const root = document.querySelector("#app");
const progressStore = createDailyReelProgressStore();
let currentActId = null;
let interaction = { text: "", selected: null, arranged: [] };
let latestState = machine.state;
let installPrompt = null;
let online = navigator.onLine;
const trackedActViews = new Set();
const trackedResults = new Set();
const recordedCompletions = new Set();
const reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)");
let transitionToken = 0;

function captureExposure() {
  posthog.capture("daily_reel_exposed", {
    eligible: Boolean(challengeCapability || rolloutEnabled),
    mode: challengeCapability ? "challenge" : requestedMode,
    publication_id: machine.publicationId,
    rollout_variant: String(rolloutValue || "disabled"),
    recovery_preview: isRecoveryPreview,
    has_rival_context: Boolean(rivalContext),
  });
}
rolloutVariant.then(captureExposure, captureExposure);

if (isRecoveryPreview) {
  posthog.capture("daily_reel_recovery_practice_loaded", {
    surface: "web",
    recovery_kind: "app_check",
  });
}

machine.subscribe((state) => {
  latestState = state;
  if (state.session?.currentAct?.id !== currentActId) {
    currentActId = state.session?.currentAct?.id || null;
    interaction = {
      text: "",
      selected: null,
      arranged: [...(state.session?.currentAct?.items || [])],
    };
  }
  trackStateMilestones(state);
  render(state);
});

window.addEventListener("beforeinstallprompt", (event) => {
  event.preventDefault();
  installPrompt = event;
  posthog.capture("daily_reel_install_available", { surface: "web" });
  render(latestState);
});

window.addEventListener("appinstalled", () => {
  installPrompt = null;
  posthog.capture("daily_reel_installed", { surface: "web" });
  toast("Daily Reel added to your home screen");
  render(latestState);
});

window.addEventListener("online", () => {
  online = true;
  render(latestState);
});

window.addEventListener("offline", () => {
  online = false;
  render(latestState);
});

root.addEventListener("click", async (event) => {
  const target = event.target.closest("[data-action]");
  if (!target) return;
  const action = target.dataset.action;
  if (action === "select") {
    interaction.selected = target.dataset.id;
    updateChoiceSelection();
    return;
  }
  if (action === "move") {
    const index = interaction.arranged.findIndex((item) => item.id === target.dataset.id);
    const destination = index + Number(target.dataset.offset);
    if (index >= 0 && destination >= 0 && destination < interaction.arranged.length) {
      [interaction.arranged[index], interaction.arranged[destination]] = [interaction.arranged[destination], interaction.arranged[index]];
      updateArrangeStage();
    }
    return;
  }
  if (action === "submit") await submitCurrentAct();
  if (action === "assist") await requestAssist(target.dataset.kind);
  if (action === "reveal") showRevealConfirmation(target);
  if (action === "cancel-reveal") target.closest(".reveal-confirmation")?.remove();
  if (action === "confirm-reveal") {
    target.closest(".reveal-confirmation")?.remove();
    await revealCurrentAct();
  }
  if (action === "retry") await retryScene(target);
  if (action === "fallback") startRecoveryPractice();
  if (action === "share") await withPendingState(target, shareResult);
  if (action === "challenge") await withPendingState(target, createChallenge);
  if (action === "copy-share") await copySharePanel(target);
  if (action === "close-share") target.closest(".share-panel")?.remove();
  if (action === "app-store") {
    posthog.capture("daily_reel_app_store_tapped", sessionProperties(latestState.session, {
      surface: "web_results",
      ticket_tier: resultTicket(latestState.session).id,
    }));
  }
  if (action === "practice") startPractice();
  if (action === "install") await promptInstall();
});

root.addEventListener("input", (event) => {
  if (event.target.matches("[data-answer]")) {
    interaction.text = event.target.value;
    const submitButton = root.querySelector('[data-action="submit"]');
    if (submitButton) submitButton.disabled = interaction.text.trim().length === 0;
  }
});

root.addEventListener("keydown", (event) => {
  if (event.key === "Enter" && event.target.matches("[data-answer]")) submitCurrentAct();
});

if (challengeCapability) await machine.claimChallenge(challengeCapability);
else await machine.load();

function render(state) {
  const currentActId = root.querySelector(".act-card")?.dataset.act || null;
  const nextActId = state.session?.currentAct?.id || null;

  if (state.phase === "submitting" && currentActId && currentActId === nextActId) {
    showSubmittingState();
    return;
  }

  const markup = `<div class="shell">${masthead()}${content(state)}</div>`;
  const hasRenderedScene = Boolean(root.firstElementChild);
  const canTransition = hasRenderedScene
    && !reducedMotion.matches
    && typeof document.startViewTransition === "function";

  const update = (animateFallback = false) => {
    root.innerHTML = markup;
    if (!animateFallback) return;
    const scene = root.querySelector(".act-card, .results-card, .message-card");
    scene?.classList.add("scene-arriving");
    scene?.addEventListener("animationend", () => scene.classList.remove("scene-arriving"), { once: true });
  };

  if (!canTransition) {
    update(hasRenderedScene && !reducedMotion.matches);
    return;
  }

  const token = ++transitionToken;
  document.documentElement.dataset.reelTransition = currentActId !== nextActId ? "advance" : "refresh";

  try {
    const transition = document.startViewTransition(() => update());
    const clearTransition = () => {
      if (token === transitionToken) delete document.documentElement.dataset.reelTransition;
    };
    transition.finished.then(clearTransition, clearTransition);
  } catch {
    delete document.documentElement.dataset.reelTransition;
    update(true);
  }
}

function showSubmittingState() {
  const card = root.querySelector(".act-card");
  if (!card) return;

  card.setAttribute("aria-busy", "true");
  card.querySelectorAll("input, button").forEach((control) => {
    control.disabled = true;
  });

  const submitButton = card.querySelector('[data-action="submit"]');
  if (submitButton) {
    submitButton.textContent = "Checking the cut...";
    submitButton.classList.add("is-checking");
  }
}

function masthead() {
  const progress = progressStore.snapshot(latestState.session?.publicationId || machine.publicationId);
  const status = !online
    ? '<span class="status-chip offline">Offline</span>'
    : progress.streak > 0
      ? `<span class="status-chip">${progress.streak} day streak</span>`
      : "";
  return `<header class="masthead">
    <div><p class="brand-kicker">Daily</p><h1 class="brand">REEL</h1></div>
    <div class="masthead-meta">${status}${isPreview ? `<span class="preview-badge">${isRecoveryPreview ? "Warm-up reel" : "Playable preview"}</span>` : ""}</div>
  </header>`;
}

function content(state) {
  if (["idle", "loading"].includes(state.phase)) return loading();
  if (state.phase === "unavailable") return message("Coming attraction", "Today's reel is being developed.", "The classic Daily Puzzle is still ready in Streaming Now.");
  if (state.phase === "failed") return failureMessage(state);
  if (state.phase === "completed") return results(state.session, state.feedback);
  return `${rivalBanner()}${progress(state.session.currentActIndex)}${actCard(state)}`;
}

function progress(index) {
  const labels = ["Decode", "Connect", "Arrange"];
  return `<div class="progress-strip" aria-label="Daily Reel progress">${labels.map((label, i) => {
    const status = i < index ? "complete" : i === index ? "active" : "";
    return `<div class="progress-frame ${status}"><span class="frame-number">${i < index ? "✓" : i + 1}</span>${label}</div>`;
  }).join("")}</div>`;
}

function actCard(state) {
  const act = state.session.currentAct;
  const number = state.session.currentActIndex + 1;
  const canUseFreeClue = supportsAssist(act, "titleLength");
  const canUseHint = supportsAssist(act, "hint");
  return `<section class="act-card" data-act="${escapeHTML(act.id)}" aria-busy="${state.phase === "submitting"}">
    <p class="eyebrow">Act ${number} / ${escapeHTML(act.role)}</p>
    <h2 class="act-title">${escapeHTML(act.title || roleTitle(act.role))}</h2>
    <p class="act-prompt">${escapeHTML(act.prompt || rolePrompt(act.role))}</p>
    ${transitionReveal(state.feedback)}
    <div class="game-stage">${roleStage(act)}</div>
    ${feedback(state.feedback)}
    <button type="button" class="primary" data-action="submit" ${canSubmit(act) && state.phase !== "submitting" ? "" : "disabled"}>
      ${state.phase === "submitting" ? "Checking the cut..." : "Lock This Scene →"}
    </button>
    <div class="assist-row">
      ${canUseFreeClue ? `<button type="button" class="utility" data-action="assist" data-kind="titleLength" ${state.session.currentProgress?.usedFreeClue ? "disabled" : ""}>✦ Clue</button>` : ""}
      ${canUseHint ? `<button type="button" class="utility" data-action="assist" data-kind="hint" ${state.session.currentProgress?.usedScoreHint ? "disabled" : ""}>💡 Hint</button>` : ""}
      <button type="button" class="utility" data-action="reveal">◉ Reveal</button>
    </div>
  </section>`;
}

function supportsAssist(act, kind) {
  const options = Array.isArray(act.assistOptions) ? act.assistOptions : [];
  if (options.length) return options.some((option) => option.kind === kind);
  return kind === "hint" || (kind === "titleLength" && act.role === "decode");
}

function roleStage(act) {
  if (act.role === "decode") {
    return `<div class="emoji-strip">${(act.emojis || []).map((emoji) => `<div class="emoji-frame">${escapeHTML(emoji)}</div>`).join("")}</div>
      ${act.clue ? `<p>${escapeHTML(act.clue)}</p>` : ""}
      <label class="visually-hidden" for="answer">Movie title</label>
      <input id="answer" class="answer-input" data-answer autocomplete="off" placeholder="Movie title" value="${escapeHTML(interaction.text)}">`;
  }
  if (act.role === "connect") {
    const films = Array.isArray(act.films) ? act.films : [];
    const options = act.options || act.choices || [];
    const sceneCopy = connectionSceneCopy(act, latestState.feedback?.answer);
    const filmFrames = films.map((film) => {
      const title = film.title || "Mystery movie";
      const posterURL = typeof film.posterPath === "string" && film.posterPath.startsWith("/")
        ? `https://image.tmdb.org/t/p/w342${film.posterPath}`
        : null;

      return `<figure class="connection-film">
        <div class="connection-poster">
          ${posterURL
            ? `<img src="${escapeHTML(posterURL)}" alt="Poster for ${escapeHTML(title)}" loading="lazy" decoding="async">`
            : `<span class="connection-poster-fallback" aria-hidden="true">No poster</span>`}
        </div>
        <figcaption>${escapeHTML(title)}</figcaption>
      </figure>`;
    }).join("");

    return `<section class="connection-context" aria-labelledby="connection-scene-title">
      <div class="connection-transition">
        <span class="connection-kicker">New scene</span>
        <strong id="connection-scene-title">${escapeHTML(sceneCopy.transition)}</strong>
      </div>
      ${filmFrames ? `<div class="connection-film-grid">${filmFrames}</div>` : ""}
      <p class="connection-question">${escapeHTML(sceneCopy.question)}</p>
    </section>
    <div class="choice-list">${options.map((option) => `<button type="button" class="choice ${interaction.selected === option.id ? "selected" : ""}" data-action="select" data-id="${escapeHTML(option.id)}" aria-pressed="${interaction.selected === option.id}"><span class="choice-marker">${interaction.selected === option.id ? "●" : "○"}</span>${escapeHTML(option.label)}</button>`).join("")}</div>`;
  }
  return `<div class="arrange-list"><p class="act-prompt">Use the arrows to edit the cut.</p>${arrangeRows()}</div>`;
}

function arrangeRows() {
  return interaction.arranged.map((item, index) => `<div class="arrange-row"><span class="arrange-index">${index + 1}</span><span class="arrange-label">${escapeHTML(item.label)}</span><button type="button" class="arrange-control" data-action="move" data-id="${escapeHTML(item.id)}" data-offset="-1" aria-label="Move ${escapeHTML(item.label)} earlier" ${index === 0 ? "disabled" : ""}>↑</button><button type="button" class="arrange-control" data-action="move" data-id="${escapeHTML(item.id)}" data-offset="1" aria-label="Move ${escapeHTML(item.label)} later" ${index === interaction.arranged.length - 1 ? "disabled" : ""}>↓</button></div>`).join("");
}

function updateChoiceSelection() {
  root.querySelectorAll(".choice").forEach((choice) => {
    const selected = choice.dataset.id === interaction.selected;
    choice.classList.toggle("selected", selected);
    choice.setAttribute("aria-pressed", String(selected));
    const marker = choice.querySelector(".choice-marker");
    if (marker) marker.textContent = selected ? "●" : "○";
  });
  const submit = root.querySelector('[data-action="submit"]');
  if (submit) submit.disabled = false;
}

function updateArrangeStage() {
  const list = root.querySelector(".arrange-list");
  if (!list) return;
  list.innerHTML = `<p class="act-prompt">Use the arrows to edit the cut.</p>${arrangeRows()}`;
  list.classList.add("is-updating");
  list.addEventListener("animationend", () => list.classList.remove("is-updating"), { once: true });
}

function feedback(value) {
  if (!value || value.advanced) return "";
  const correct = value.type === "correct";
  const title = correct ? "Scene locked" : value.type === "incorrect" ? "Try another cut" : value.type === "assist" ? "Clue from the booth" : "Scene revealed";
  return `<div class="feedback ${correct ? "correct" : ""}"><strong>${correct ? "✓" : "✦"}</strong><p><b>${title}</b>${value.text ? `<br>${escapeHTML(value.text)}` : ""}</p></div>`;
}

function transitionReveal(value) {
  if (!value?.advanced || !value.text) return "";
  const role = value.role ? value.role[0].toUpperCase() + value.role.slice(1) : "Scene";
  const title = value.answer || (value.type === "revealed" ? "The answer is in" : "Scene locked");
  return `<aside class="transition-reveal ${value.type === "revealed" ? "was-revealed" : ""}" aria-live="polite">
    <span class="transition-reveal-mark" aria-hidden="true">✓</span>
    <div><p class="transition-reveal-kicker">${escapeHTML(role)} revealed</p><h3>${escapeHTML(title)}</h3><p>${escapeHTML(value.text)}</p></div>
  </aside>`;
}

function finalReveal(value, theme) {
  const completionThread = completionThreadFor(value, theme);
  const explanation = completionThread?.explanation || value?.text;
  if (!explanation) return `<div class="result-acts">${["Decode", "Connect", "Arrange"].map((label) => `<div class="result-act">✓<br>${label}</div>`).join("")}</div>`;
  return `<section class="final-reveal" aria-label="Final reveal">
    <p class="transition-reveal-kicker">The final reveal</p>
    <h3>${escapeHTML(completionThread?.title || theme || "The full picture")}</h3>
    <p>${escapeHTML(explanation)}</p>
  </section>`;
}

function results(session, lastFeedback) {
  const festival = progressStore.snapshot(session.publicationId);
  const isDaily = session.mode === "daily";
  const ticket = resultTicket(session);
  const eyebrow = session.mode === "challenge" ? "Challenge complete" : isRecoveryPreview ? "Warm-up complete" : session.mode === "practice" ? "Encore complete" : "That's a wrap";
  const storeCopy = appStoreResultCopy();
  const festivalStamps = Array.from({ length: festival.festivalTarget }, (_, index) => {
    const filled = index < festival.festivalCount;
    const current = filled && festival.completedToday && index === festival.festivalCount - 1;
    return `<span class="festival-stamp ${filled ? "filled" : ""} ${current ? "current" : ""}" aria-label="Festival day ${index + 1}: ${filled ? "complete" : "open"}"><span>${filled ? "✓" : index + 1}</span><small>DAY</small></span>`;
  }).join("");
  const remaining = Math.max(0, festival.festivalTarget - festival.festivalCount);
  const festivalReward = festival.festivalComplete
    ? "Marquee Five badge unlocked. Your pass is complete."
    : `${remaining} more Daily Reel${remaining === 1 ? "" : "s"} unlocks the Marquee Five badge.`;
  return `${progress(3)}<section class="results-card">
    <p class="eyebrow results-eyebrow">${eyebrow}</p>
    <div class="score">${Number(session.totalScore || 0).toLocaleString()}</div>
    <p class="score-label">FINAL CUT SCORE</p>
    ${finalReveal(lastFeedback, session.theme)}
    ${rivalResultCard(session)}
    <section class="festival-card ${festival.festivalComplete ? "complete" : ""}" aria-label="Festival progress">
      <div class="festival-ticket">
        <span class="ticket-icon" aria-hidden="true">🎟</span>
        <div class="ticket-copy"><span>${isDaily ? "TODAY'S COLLECTIBLE" : isRecoveryPreview ? "WARM-UP COLLECTIBLE" : "ENCORE TICKET"}</span><strong>${ticket.title}</strong></div>
        <div class="ticket-serial"><span>${ticket.serial}</span><small>${Number(session.totalScore || 0).toLocaleString()} PTS</small></div>
      </div>
      <div class="festival-heading">
        <div><span class="festival-kicker">7-day Festival</span><strong>${festival.festivalCount} of ${festival.festivalTarget} Daily Reels</strong></div>
        <span class="festival-streak">${festival.streak ? `${festival.streak} day streak` : "Start a streak"}</span>
      </div>
      <div class="festival-track" aria-label="${festival.festivalCount} of ${festival.festivalTarget} completed">${festivalStamps}</div>
      ${isDaily ? `<p class="festival-reward">${festivalReward}</p>` : ""}
      <p class="next-reel">${isDaily ? `Next Reel in <b data-countdown>${nextReelCountdown()}</b>` : isRecoveryPreview ? "<b>Warm-up complete.</b> Return for a verified Reel and a Festival stamp." : "Encore runs do not change Daily Festival progress."}</p>
    </section>
    <div class="result-actions">
      <button class="primary" data-action="practice">↻ Encore This Reel</button>
      <div class="result-action-pair">
        <button type="button" class="secondary" data-action="challenge">♟ Challenge</button>
        <button type="button" class="secondary" data-action="share">↗ Share My Cut</button>
      </div>
      <a class="app-store-cta" data-action="app-store" href="${escapeHTML(appStoreURL)}" target="_blank" rel="noopener noreferrer"><span>${escapeHTML(storeCopy.kicker)}</span><strong>${escapeHTML(storeCopy.action)}</strong></a>
      ${installCTA()}
    </div>
  </section>`;
}

function loading() {
  return `<div class="loader" role="status"><div><div class="reel-icon">🎞️</div><p class="eyebrow">Threading today's reel</p><p class="loader-copy">Checking the projector and saving your seat…</p><div class="loader-track" aria-hidden="true"><span></span></div><p class="loader-acts">Decode · Connect · Arrange</p></div></div>`;
}

function message(eyebrow, title, copy, retry = false) {
  return `<section class="message-card"><p class="eyebrow">${eyebrow}</p><h1>${title}</h1><p class="message-copy">${copy}</p>${retry ? '<button type="button" class="primary" data-action="retry">Retry Scene</button>' : ""}</section>`;
}

function failureMessage(state) {
  const appCheckBlocked = state.recoveryKind === "app_check";
  const copy = appCheckBlocked
    ? rivalContext
      ? `Your friend's ${rivalContext.score.toLocaleString()}-point challenge is safe. Warm up now while we reconnect the head-to-head Reel.`
      : "Today's verified Reel could not start in this browser. Your place is safe, and a warm-up Reel is ready now."
    : "Your place is saved. Reconnect and continue with the same reel.";
  return `<section class="message-card recovery-card" data-error-code="${escapeHTML(state.errorCode)}">
    <p class="eyebrow">Projection paused</p>
    <h1>We lost the picture.</h1>
    <p class="message-copy">${copy}</p>
    <div class="message-actions">
      ${appCheckBlocked ? '<button type="button" class="primary" data-action="fallback">Play the Warm-up Reel →</button>' : '<button type="button" class="primary" data-action="retry">Retry Scene</button>'}
      ${appCheckBlocked ? '<button type="button" class="secondary" data-action="retry">Try the verified Reel again</button>' : ""}
    </div>
    ${appCheckBlocked ? '<p class="recovery-note">The warm-up earns a collectible without changing today\'s verified streak.</p>' : ""}
  </section>`;
}

async function withPendingState(target, work) {
  if (!target || target.classList.contains("is-checking")) return;
  target.classList.add("is-checking");
  target.setAttribute("aria-busy", "true");
  try {
    return await work();
  } finally {
    if (target.isConnected) {
      target.classList.remove("is-checking");
      target.removeAttribute("aria-busy");
    }
  }
}

async function retryScene(target) {
  posthog.capture("daily_reel_retry_tapped", {
    error_code: latestState.errorCode || "unknown",
    recovery_kind: latestState.recoveryKind || "network",
    surface: "web",
  });
  target.disabled = true;
  target.textContent = "Re-threading the reel…";
  target.closest(".message-card")?.setAttribute("aria-busy", "true");
  await new Promise((resolve) => setTimeout(resolve, 360));
  await machine.retry();
}

function startRecoveryPractice() {
  posthog.capture("daily_reel_recovery_practice_tapped", {
    error_code: latestState.errorCode || "app_check.unavailable",
    recovery_kind: "app_check",
    surface: "web",
  });
  const url = new URL(location.origin + location.pathname);
  url.searchParams.set("preview", "1");
  url.searchParams.set("recovery", "app-check");
  url.searchParams.set("mode", "practice");
  url.searchParams.set("scope", crypto.randomUUID());
  if (rivalContext) {
    url.searchParams.set("rival_score", String(rivalContext.score));
    url.searchParams.set("rival_cut", rivalContext.cut);
  }
  location.assign(url);
}

async function submitCurrentAct() {
  const act = latestState.session?.currentAct;
  if (!act || latestState.phase !== "playing" || !canSubmit(act)) return;
  posthog.capture("daily_reel_attempt_submitted", sessionProperties(latestState.session, {
    act_role: act.role,
    attempt_number: Number(latestState.session.currentProgress?.incorrectAttempts || latestState.session.currentProgress?.attempts || 0) + 1,
  }));
  if (act.role === "decode") await machine.submit(interaction.text.trim());
  if (act.role === "connect") await machine.submit(interaction.selected);
  if (act.role === "arrange") await machine.submit(interaction.arranged.map((item) => item.id));
}

async function shareResult() {
  const session = latestState.session;
  const festival = progressStore.snapshot(session.publicationId);
  const ticket = resultTicket(session);
  const marks = resultMarks(session);
  const headToHead = rivalResult(session.totalScore, rivalContext);
  const text = resultShareText({
    publicationId: session.publicationId,
    marks,
    score: session.totalScore,
    ticketTitle: ticket.title,
    festivalCount: festival.festivalCount,
    festivalTarget: festival.festivalTarget,
    streak: festival.streak,
    recoveryPreview: isRecoveryPreview,
    rivalHeadline: headToHead?.title,
  });
  const url = decorateChallengeURL(canonicalURL(), { score: session.totalScore, cut: ticket.title });
  const shareProperties = {
    festival_count: festival.festivalCount,
    festival_target: festival.festivalTarget,
    streak_days: festival.streak,
    ticket_tier: ticket.id,
    rival_outcome: headToHead?.outcome,
    score_delta: headToHead?.delta,
  };
  posthog.capture("daily_reel_result_share_tapped", sessionProperties(session, shareProperties));
  try {
    let shareFormat = "text";
    const shareData = { title: "Daily Reel", text, url };
    const image = await createResultShareImage(session, festival);
    if (image && typeof navigator.canShare === "function" && navigator.canShare({ files: [image] })) {
      shareData.files = [image];
      shareFormat = "image";
    }
    const delivery = await deliverShare({
      navigatorRef: navigator,
      shareData,
      fallbackText: `${text}\n${url}`,
      presentFallback: (value) => showSharePanel({
        kind: "result",
        title: "Share your Final Cut",
        copy: "Copy your score card and drop it into Messages, a group chat, or social post.",
        value,
      }),
    });
    if (delivery.outcome === "shared") {
      posthog.capture("daily_reel_result_shared", sessionProperties(session, { ...shareProperties, share_format: shareFormat }));
    }
    if (delivery.outcome === "fallback") {
      posthog.capture("daily_reel_share_fallback_viewed", sessionProperties(session, { share_kind: "result" }));
    }
  } catch (error) {
    if (error?.name !== "AbortError") toast("Sharing is not available in this browser");
  }
}

async function createChallenge() {
  const session = latestState.session;
  const festival = progressStore.snapshot(session.publicationId);
  const ticket = resultTicket(session);
  let challenge;
  try {
    challenge = await client.createChallenge({
      sourceSessionCapability: latestState.capability,
      requestId: crypto.randomUUID(),
    });
    posthog.capture("daily_reel_challenge_created", {
      ...contentAttribution(latestState.session, machine.publicationId),
      config_hash: latestState.session?.configId,
      festival_count: festival.festivalCount,
      streak_days: festival.streak,
      ticket_tier: ticket.id,
      surface: "web",
      rollout_variant: String(rolloutValue || "disabled"),
    });
  } catch (error) {
    posthog.capture("daily_reel_challenge_creation_failed", {
      error_code: error?.code || "network_or_decode",
      surface: "web",
      rollout_variant: String(rolloutValue || "disabled"),
    });
    toast(isPreview ? "Preview challenge link is ready on supported browsers" : "Challenge could not be created yet");
    return;
  }

  try {
    const text = `I scored ${Number(session.totalScore || 0).toLocaleString()} points and earned a ${ticket.title}. Can you beat my Daily Reel cut?`;
    const challengeURL = decorateChallengeURL(challenge.shareUrl, {
      score: session.totalScore,
      cut: ticket.title,
    });
    let shareFormat = "text";
    const shareData = { title: "Can you beat my Daily Reel?", text, url: challengeURL };
    const image = await createResultShareImage(session, festival);
    if (image && typeof navigator.canShare === "function" && navigator.canShare({ files: [image] })) {
      shareData.files = [image];
      shareFormat = "image";
    }
    const delivery = await deliverShare({
      navigatorRef: navigator,
      shareData,
      fallbackText: `${text}\n${challengeURL}`,
      presentFallback: (value) => showSharePanel({
        kind: "challenge",
        title: "Send the challenge",
        copy: "Copy this private challenge link and send it to one movie friend.",
        value,
      }),
    });
    if (delivery.outcome === "shared") {
      posthog.capture("daily_reel_challenge_shared", sessionProperties(session, {
        festival_count: festival.festivalCount,
        streak_days: festival.streak,
        ticket_tier: ticket.id,
        share_format: shareFormat,
      }));
    }
    if (delivery.outcome === "fallback") {
      posthog.capture("daily_reel_share_fallback_viewed", sessionProperties(session, { share_kind: "challenge" }));
    }
  } catch (error) {
    if (error?.name !== "AbortError") toast("Challenge created, but sharing is unavailable");
  }
}

function showSharePanel({ kind, title, copy, value }) {
  root.querySelector(".share-panel")?.remove();
  const panel = document.createElement("section");
  panel.className = "share-panel";
  panel.dataset.shareKind = kind;
  panel.setAttribute("role", "dialog");
  panel.setAttribute("aria-label", title);
  panel.innerHTML = `<p class="transition-reveal-kicker">Ready for the group chat</p><h3>${escapeHTML(title)}</h3><p>${escapeHTML(copy)}</p><textarea class="share-copy" readonly aria-label="Share text">${escapeHTML(value)}</textarea><div class="share-panel-actions"><button type="button" class="secondary" data-action="close-share">Not now</button><button type="button" class="primary" data-action="copy-share">Copy to clipboard</button></div>`;
  root.querySelector(".results-card")?.append(panel);
  panel.querySelector(".share-copy")?.focus({ preventScroll: true });
  panel.scrollIntoView({ block: "nearest", behavior: reducedMotion.matches ? "auto" : "smooth" });
}

async function copySharePanel(target) {
  const panel = target.closest(".share-panel");
  const field = panel?.querySelector(".share-copy");
  if (!field) return;
  let copied = false;
  try {
    if (navigator.clipboard?.writeText) {
      await navigator.clipboard.writeText(field.value);
      copied = true;
    }
  } catch {
    copied = false;
  }
  if (!copied) {
    field.focus();
    field.select();
    copied = document.execCommand?.("copy") === true;
  }
  target.textContent = copied ? "Copied ✓" : "Text selected";
  posthog.capture(copied ? "daily_reel_share_copy_completed" : "daily_reel_share_copy_selected", sessionProperties(latestState.session, {
    share_kind: panel.dataset.shareKind || "result",
  }));
  toast(copied ? "Ready to send" : "Press Copy in your browser");
}

async function requestAssist(kind) {
  const normalizedKind = kind === "clue" ? "titleLength" : kind;
  posthog.capture("daily_reel_assist_requested", sessionProperties(latestState.session, {
    act_role: latestState.session?.currentAct?.role,
    assistance_category: normalizedKind,
  }));
  await machine.assist(normalizedKind);
}

function showRevealConfirmation(target) {
  const card = target.closest(".act-card");
  if (!card || card.querySelector(".reveal-confirmation")) return;
  const panel = document.createElement("div");
  panel.className = "reveal-confirmation";
  panel.setAttribute("role", "dialog");
  panel.setAttribute("aria-label", "Reveal this scene");
  panel.innerHTML = `<div><p class="transition-reveal-kicker">Call in the editor?</p><strong>Reveal this scene and keep the run.</strong><span>The answer will cost points, but the story continues.</span></div>
    <div class="reveal-confirmation-actions"><button class="secondary" data-action="cancel-reveal">Keep playing</button><button class="primary" data-action="confirm-reveal">Reveal the cut</button></div>`;
  card.querySelector(".assist-row")?.insertAdjacentElement("afterend", panel);
  panel.querySelector('[data-action="cancel-reveal"]')?.focus();
}

async function revealCurrentAct() {
  posthog.capture("daily_reel_assist_requested", sessionProperties(latestState.session, {
    act_role: latestState.session?.currentAct?.role,
    assistance_category: "reveal",
  }));
  await machine.reveal();
}

function startPractice() {
  posthog.capture("daily_reel_encore_started", sessionProperties(latestState.session));
  const url = new URL(location.origin + location.pathname);
  if (isPreview) url.searchParams.set("preview", "1");
  if (isRecoveryPreview) url.searchParams.set("recovery", "app-check");
  url.searchParams.set("mode", "practice");
  url.searchParams.set("scope", crypto.randomUUID());
  location.assign(url);
}

function rivalBanner() {
  if (!rivalContext) return "";
  return `<aside class="rival-banner" aria-label="Friend challenge"><span>HEAD-TO-HEAD</span><strong>Score to beat: ${rivalContext.score.toLocaleString()}</strong><small>${escapeHTML(rivalContext.cut)}</small></aside>`;
}

function rivalResultCard(session) {
  const result = rivalResult(session?.totalScore, rivalContext);
  if (!result) return "";
  const detail = result.outcome === "won"
    ? "Your cut takes the lead. Send the result back."
    : result.outcome === "lost"
      ? "The rematch is ready whenever you are."
      : "Same score. The rematch decides it.";
  return `<section class="rival-result ${result.outcome}" aria-label="Challenge result"><p class="transition-reveal-kicker">Head-to-head result</p><h3>${escapeHTML(result.title)}</h3><p>${detail}</p></section>`;
}

async function promptInstall() {
  posthog.capture("daily_reel_install_tapped", sessionProperties(latestState.session));
  if (installPrompt) {
    await installPrompt.prompt();
    const choice = await installPrompt.userChoice;
    posthog.capture("daily_reel_install_response", { outcome: choice.outcome, surface: "web" });
    if (choice.outcome === "accepted") installPrompt = null;
    return;
  }
  toast(isIOS() ? "In Safari, tap Share, then Add to Home Screen" : "Use your browser menu to install Daily Reel");
}

function installCTA() {
  if (isStandalone()) return "";
  return `<button class="install-button" data-action="install">＋ Add Daily Reel to Home Screen</button>`;
}

function trackStateMilestones(state) {
  const session = state.session;
  if (!session) return;
  const sessionKey = session.sessionId || `${session.publicationId}:${session.mode}`;
  if (state.phase === "playing" && session.currentAct) {
    const actKey = `${sessionKey}:${session.currentActIndex}`;
    if (!trackedActViews.has(actKey)) {
      trackedActViews.add(actKey);
      posthog.capture("daily_reel_act_viewed", sessionProperties(session, {
        act_role: session.currentAct.role,
      }));
    }
  }
  if (state.phase !== "completed") return;
  if (!recordedCompletions.has(sessionKey)) {
    recordedCompletions.add(sessionKey);
    const outcome = progressStore.recordCompletion(session);
    if (outcome.changed) {
      posthog.capture("daily_reel_festival_progressed", sessionProperties(session, {
        festival_count: outcome.festivalCount,
        festival_target: outcome.festivalTarget,
        streak_days: outcome.streak,
      }));
    }
    if (outcome.badgeAwarded) {
      posthog.capture("daily_reel_badge_awarded", sessionProperties(session, {
        badge: "five_reel_festival",
      }));
    }
  }
  if (!trackedResults.has(sessionKey)) {
    trackedResults.add(sessionKey);
    const festival = progressStore.snapshot(session.publicationId);
    posthog.capture("daily_reel_results_viewed", sessionProperties(session, {
      festival_count: festival.festivalCount,
      festival_target: festival.festivalTarget,
      festival_complete: festival.festivalComplete,
      streak_days: festival.streak,
      ticket_tier: resultTicket(session).id,
    }));
  }
}

function sessionProperties(session, extra = {}) {
  return {
    mode: session?.mode || requestedMode,
    locale: session?.locale || config.locale || navigator.language || "en",
    ...contentAttribution(session, machine.publicationId),
    config_hash: session?.configId || session?.experienceConfigHash,
    act_index: session?.currentActIndex,
    score: session?.totalScore,
    rollout_variant: String(rolloutValue || "disabled"),
    recovery_preview: isRecoveryPreview,
    rival_score: rivalContext?.score,
    has_rival_context: Boolean(rivalContext),
    ...extra,
  };
}

function canonicalURL() {
  return new URL("/", location.origin).toString();
}

function resultMarks(session) {
  const acts = Array.isArray(session?.acts) && session.acts.length ? session.acts : [null, null, null];
  return acts.slice(0, 3).map((act) => act?.status === "revealed" ? "🟨" : "🟩").join("");
}

function resultTicket(session) {
  const score = Math.max(0, Number(session?.totalScore || 0));
  const tier = score >= 2_700
    ? { id: "premiere_cut", title: "Premiere Cut" }
    : score >= 2_100
      ? { id: "directors_cut", title: "Director's Cut" }
      : { id: "final_cut", title: "Final Cut" };
  const dateCode = String(session?.publicationId || "reel").replaceAll("-", "").slice(-4).toUpperCase();
  return { ...tier, serial: `#${dateCode}-${String(score).padStart(4, "0")}` };
}

async function createResultShareImage(session, festival) {
  if (typeof File !== "function") return null;
  const canvas = document.createElement("canvas");
  canvas.width = 1080;
  canvas.height = 1350;
  const context = canvas.getContext("2d");
  if (!context) return null;
  if (document.fonts?.ready) await document.fonts.ready.catch(() => undefined);

  const score = Math.max(0, Number(session?.totalScore || 0));
  const ticket = resultTicket(session);
  const background = context.createLinearGradient(0, 0, 1080, 1350);
  background.addColorStop(0, "#2b090f");
  background.addColorStop(.5, "#12070a");
  background.addColorStop(1, "#050505");
  context.fillStyle = background;
  context.fillRect(0, 0, 1080, 1350);

  context.fillStyle = "#ffb238";
  context.fillRect(72, 72, 10, 1206);
  context.fillStyle = "#f7eee4";
  context.font = "800 42px 'Barlow Condensed', sans-serif";
  context.fillText("STREAMING NOW FILM CLUB", 122, 145);
  context.fillStyle = "#ffb238";
  context.font = "900 168px 'Barlow Condensed', sans-serif";
  context.fillText("DAILY", 122, 330);
  context.fillStyle = "#f7eee4";
  context.fillText("REEL", 122, 475);
  context.fillStyle = "#9f9294";
  context.font = "600 38px 'DM Sans', sans-serif";
  context.fillText(String(session?.publicationId || "Today's cut"), 128, 548);

  context.fillStyle = "#f7eee4";
  context.font = "900 210px 'Barlow Condensed', sans-serif";
  context.fillText(score.toLocaleString(), 122, 790);
  context.fillStyle = "#9f9294";
  context.font = "800 34px 'Barlow Condensed', sans-serif";
  context.fillText("FINAL CUT SCORE", 128, 842);

  const acts = Array.isArray(session?.acts) && session.acts.length ? session.acts : [null, null, null];
  ["DECODE", "CONNECT", "ARRANGE"].forEach((label, index) => {
    const x = 128 + (index * 282);
    context.fillStyle = acts[index]?.status === "revealed" ? "#ffb238" : "#3bd17f";
    context.fillRect(x, 905, 62, 62);
    context.fillStyle = "#f7eee4";
    context.font = "800 27px 'Barlow Condensed', sans-serif";
    context.fillText(label, x + 78, 949);
  });

  context.fillStyle = "rgba(255,255,255,.08)";
  context.fillRect(122, 1035, 836, 2);
  context.fillStyle = "#ffb238";
  context.font = "900 48px 'Barlow Condensed', sans-serif";
  context.fillText(ticket.title.toUpperCase(), 122, 1115);
  context.fillStyle = "#9f9294";
  context.font = "600 30px 'DM Sans', sans-serif";
  context.fillText(`FESTIVAL ${festival.festivalCount}/${festival.festivalTarget}${festival.streak ? `  ·  ${festival.streak} DAY STREAK` : ""}`, 122, 1170);
  context.fillStyle = "#f7eee4";
  context.font = "700 28px 'DM Sans', sans-serif";
  context.fillText("Decode. Connect. Arrange. Then challenge a friend.", 122, 1240);

  const blob = await new Promise((resolve) => canvas.toBlob(resolve, "image/png"));
  return blob ? new File([blob], `daily-reel-${session?.publicationId || "result"}.png`, { type: "image/png" }) : null;
}

function isStandalone() {
  return matchMedia("(display-mode: standalone)").matches || navigator.standalone === true;
}

function isIOS() {
  return /iPad|iPhone|iPod/.test(navigator.userAgent) || (navigator.platform === "MacIntel" && navigator.maxTouchPoints > 1);
}

function canSubmit(act) {
  if (act.role === "decode") return interaction.text.trim().length > 0;
  if (act.role === "connect") return Boolean(interaction.selected);
  return interaction.arranged.length > 0;
}

function roleTitle(role) {
  return { decode: "Name the movie", connect: "Find the connection", arrange: "Cut it in order" }[role];
}

function rolePrompt(role) {
  return { decode: "Turn the visual clue into a title.", connect: "Choose the detail that connects.", arrange: "Put the story beats in order." }[role];
}

function toast(message) {
  const element = document.createElement("div");
  element.className = "toast";
  element.setAttribute("role", "status");
  element.textContent = message;
  document.body.append(element);
  setTimeout(() => element.remove(), 2600);
}

setInterval(() => {
  const countdown = root.querySelector("[data-countdown]");
  if (countdown) countdown.textContent = nextReelCountdown();
}, 60_000);

function escapeHTML(value) {
  return String(value ?? "").replace(/[&<>'"]/g, (character) => ({
    "&": "&amp;", "<": "&lt;", ">": "&gt;", "'": "&#39;", '"': "&quot;",
  })[character]);
}
