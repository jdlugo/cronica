import { contentAttribution } from "./session-telemetry.js?v=1";

export class DailyReelMachine {
  constructor({ client, capabilities, publicationId, locale, mode = "daily", scopeId = null, requestId = () => crypto.randomUUID(), track = () => {} }) {
    this.client = client;
    this.capabilities = capabilities;
    this.publicationId = publicationId;
    this.locale = locale;
    this.mode = mode;
    this.scopeId = scopeId;
    this.requestId = requestId;
    this.track = track;
    this.listeners = new Set();
    this.state = {
      phase: "idle",
      session: null,
      capability: null,
      feedback: null,
      canRetry: false,
      errorCode: null,
      errorMessage: null,
      recoveryKind: null,
    };
    this.pending = null;
  }

  subscribe(listener) {
    this.listeners.add(listener);
    listener(this.state);
    return () => this.listeners.delete(listener);
  }

  async load() {
    if (!["idle", "failed", "unavailable"].includes(this.state.phase)) return;
    this.#set({ phase: "loading", feedback: null, canRetry: false, errorCode: null, errorMessage: null, recoveryKind: null });
    const saved = this.capabilities.load(this.publicationId, this.mode, this.scopeId);
    if (saved) {
      try {
        const session = await this.client.resume(saved);
        this.#accept(session, saved, "daily_reel_session_resumed");
        return;
      } catch (error) {
        if (["session.not_found", "session.expired", "content.unavailable"].includes(error.code)) {
          this.capabilities.clear(this.publicationId, this.mode, this.scopeId);
        } else {
          this.#fail(error, true);
          return;
        }
      }
    }
    try {
      const envelope = await this.client.start({
        publicationId: this.publicationId,
        locale: this.locale,
        mode: this.mode,
        scopeId: this.scopeId,
      });
      this.capabilities.save(this.publicationId, this.mode, envelope.capability, this.scopeId);
      this.#accept(envelope.session, envelope.capability, "daily_reel_session_started");
    } catch (error) {
      if (error.code === "experience.ineligible" || error.code === "content.unavailable" || error.statusCode === 404) {
        this.#set({ phase: "unavailable" });
      } else {
        this.#fail(error, true);
      }
    }
  }

  async claimChallenge(challengeCapability) {
    if (!challengeCapability || !["idle", "failed", "unavailable"].includes(this.state.phase)) return;
    this.#set({ phase: "loading", feedback: null, canRetry: false, errorCode: null, errorMessage: null, recoveryKind: null });
    try {
      const claimed = await this.client.claimChallenge(challengeCapability);
      this.publicationId = claimed.challenge.publicationId;
      this.locale = claimed.challenge.locale;
      this.mode = "challenge";
      this.scopeId = claimed.challenge.challengeId || null;
      this.capabilities.save(this.publicationId, this.mode, claimed.sessionCapability, this.scopeId);
      const session = await this.client.resume(claimed.sessionCapability);
      this.#accept(session, claimed.sessionCapability, "daily_reel_challenge_claimed");
    } catch (error) {
      this.#fail(error, true);
    }
  }

  submit(answer) {
    return this.#perform({ type: "attempt", answer, requestId: this.requestId(), sequence: this.state.session?.sequence });
  }

  assist(kind) {
    return this.#perform({ type: "assist", kind, requestId: this.requestId(), sequence: this.state.session?.sequence });
  }

  reveal() {
    return this.#perform({ type: "reveal", requestId: this.requestId(), sequence: this.state.session?.sequence });
  }

  retry() {
    return this.pending ? this.#perform(this.pending) : this.load();
  }

  async #perform(action) {
    if (!this.state.capability || !["playing", "failed"].includes(this.state.phase)) return;
    const mutationActIndex = this.state.session?.currentActIndex;
    const mutationAct = this.state.session?.currentAct;
    const mutationActRole = mutationAct?.role;
    this.pending = action;
    this.#set({ phase: "submitting", canRetry: false });
    const base = {
      capability: this.state.capability,
      expectedSequence: action.sequence,
      requestId: action.requestId,
    };
    try {
      let response;
      if (action.type === "attempt") response = await this.client.submitAttempt({ ...base, answer: action.answer });
      if (action.type === "assist") response = await this.client.requestAssist({ ...base, kind: action.kind });
      if (action.type === "reveal") response = await this.client.reveal(base);
      this.pending = null;
      const remainsOnMutationAct = response.session.completedAt == null
        && response.session.currentActIndex === mutationActIndex;
      const advanced = !remainsOnMutationAct;
      const reveal = response.reveal
        ? normalizeReveal(response.reveal, mutationActRole)
        : response.correct === true && advanced
          ? fallbackSolvedReveal(mutationAct, action.answer)
          : null;
      const feedback = response.assist
        ? { type: "assist", role: mutationActRole, text: extractText(response.assist) }
        : reveal
          ? {
            type: action.type === "reveal" || response.correct === false ? "revealed" : "correct",
            role: reveal.role,
            answer: reveal.answer,
            text: reveal.explanation,
            advanced,
            ...(reveal.threadTitle ? {
              threadTitle: reveal.threadTitle,
              threadExplanation: reveal.threadExplanation,
            } : {}),
          }
          : typeof response.correct === "boolean"
            ? {
              type: response.correct ? "correct" : "incorrect",
              role: mutationActRole,
              text: response.correct ? "" : incorrectFeedback(mutationAct),
              advanced,
            }
            : null;
      this.#accept(response.session, this.state.capability, null, feedback);
    } catch (error) {
      if (error?.code === "session.stale_sequence") {
        try {
          const session = await this.client.resume(this.state.capability);
          this.pending = null;
          this.#accept(session, this.state.capability);
          return;
        } catch (resumeError) {
          this.#fail(resumeError, true);
          return;
        }
      }
      this.#fail(error, true);
    }
  }

  #accept(session, capability, event = null, feedback = null) {
    session = normalizeSession(session);
    const phase = session.completedAt != null ? "completed" : "playing";
    this.#set({
      phase,
      session,
      capability,
      feedback,
      canRetry: false,
      errorCode: null,
      errorMessage: null,
      recoveryKind: null,
    });
    if (event) this.track(event, telemetryProperties(session));
    if (phase === "completed") this.track("daily_reel_completed", telemetryProperties(session));
  }

  #fail(error, canRetry = false) {
    const code = error?.code || "network_or_decode";
    const recoveryKind = code === "app_check.unavailable" ? "app_check" : "network";
    this.#set({
      phase: "failed",
      errorCode: code,
      errorMessage: error?.message || "Daily Reel could not continue",
      recoveryKind,
      canRetry,
    });
    this.track("daily_reel_failed", {
      error_code: code,
      provider_code: error?.providerCode,
      recovery_kind: recoveryKind,
    });
  }

  #set(patch) {
    this.state = { ...this.state, ...patch };
    for (const listener of this.listeners) listener(this.state);
  }
}

function extractText(value) {
  if (typeof value === "string") return value;
  if (Array.isArray(value)) return value.map(extractText).filter(Boolean).join(" -> ");
  if (value && typeof value === "object") {
    if (Number.isFinite(value.titleLength)) return `${value.titleLength} characters in the title.`;
    return extractText(value.text ?? value.explanation ?? value.title ?? value.answer ?? value.value);
  }
  return "Study every detail in the scene.";
}

function normalizeReveal(value, fallbackRole) {
  if (!value || typeof value !== "object") {
    return { role: fallbackRole, answer: null, explanation: extractText(value) };
  }
  return {
    role: value.role || fallbackRole,
    answer: typeof value.title === "string" ? value.title : null,
    explanation: typeof value.explanation === "string" ? value.explanation : extractText(value),
    ...(typeof value.threadTitle === "string" && typeof value.threadExplanation === "string" ? {
      threadTitle: value.threadTitle,
      threadExplanation: value.threadExplanation,
    } : {}),
  };
}

function incorrectFeedback(act) {
  const role = typeof act === "string" ? act : act?.role;
  if (role === "decode") return "That title misses one of the symbols. Read the clue from left to right.";
  if (role === "connect") {
    const films = Array.isArray(act?.films) ? act.films : [];
    return films.length >= 2
      ? "One frame breaks that connection. Test the choice against all three movies."
      : "That detail does not fit this movie. Recheck the release clue and try another cut.";
  }
  if (role === "arrange") return "The timeline still jumps backward. Anchor the oldest movie first.";
  return "One detail does not fit yet. Take another look.";
}

function fallbackSolvedReveal(act, answer) {
  if (!act) return { role: null, answer: null, explanation: "The scene fits. Keep following the reel." };
  if (act.role === "decode") {
    const symbols = Array.isArray(act.emojis) ? act.emojis.join(" + ") : "Every symbol";
    return { role: act.role, answer: String(answer), explanation: `${symbols} resolves to ${answer}.` };
  }
  if (act.role === "connect") {
    const selected = act.options?.find((option) => option.id === answer);
    return {
      role: act.role,
      answer: selected?.label || "Connection found",
      explanation: "That connection holds across all three movies.",
    };
  }
  if (act.role === "arrange") {
    const labels = Array.isArray(answer)
      ? answer.map((id) => act.items?.find((item) => item.id === id)?.label).filter(Boolean)
      : [];
    return {
      role: act.role,
      answer: "Timeline locked",
      explanation: labels.length ? `The final cut runs ${labels.join(" -> ")}.` : "The timeline now runs from earliest to latest.",
    };
  }
  return { role: act.role, answer: null, explanation: "The scene fits. Keep following the reel." };
}

function telemetryProperties(session) {
  return {
    mode: session.mode,
    locale: session.locale,
    ...contentAttribution(session, session.publicationId),
    config_hash: session.configId || session.experienceConfigHash,
    act_index: session.currentActIndex,
    score: session.totalScore,
  };
}

function normalizeSession(session) {
  const currentAct = session.currentAct ? {
    ...session.currentAct,
    emojis: session.currentAct.emoji || session.currentAct.emojis || [],
    options: session.currentAct.choices || session.currentAct.options || [],
    items: (session.currentAct.films || session.currentAct.items || []).map((item) => ({
      id: item.id,
      label: item.label || item.title,
    })),
  } : null;
  return {
    ...session,
    currentAct,
    currentProgress: session.currentProgress || session.acts?.[session.currentActIndex] || null,
  };
}
export function completionThreadFor(value, fallbackTheme) {
  const seen = new Set();

  function findThread(candidate) {
    if (!candidate || typeof candidate !== "object" || seen.has(candidate)) return null;
    seen.add(candidate);

    if (typeof candidate.threadTitle === "string" && typeof candidate.threadExplanation === "string") {
      return {
        title: candidate.threadTitle,
        explanation: candidate.threadExplanation,
      };
    }

    if (
      candidate.role === "arrange"
      && typeof candidate.title === "string"
      && candidate.title.trim()
      && candidate.title !== fallbackTheme
      && typeof candidate.explanation === "string"
      && candidate.explanation.trim()
    ) {
      return {
        title: candidate.title,
        explanation: candidate.explanation,
      };
    }

    for (const nested of Object.values(candidate)) {
      const result = findThread(nested);
      if (result) return result;
    }
    return null;
  }

  return findThread(value);
}
