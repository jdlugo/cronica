import assert from "node:assert/strict";
import test from "node:test";
import { DailyReelClientError } from "../src/daily-reel-client.js";
import { DailyReelMachine } from "../src/daily-reel-machine.js";

function session(overrides = {}) {
  return {
    sessionId: "s1",
    publicationId: "2026-08-28",
    versionId: "v1",
    locale: "en",
    mode: "daily",
    configId: "config-1",
    sequence: 0,
    currentActIndex: 0,
    currentAct: { id: "decode", role: "decode" },
    expiresAt: Date.now() + 100_000,
    ...overrides,
  };
}

function capabilityStore(initial = null) {
  let value = initial;
  return {
    load: () => value,
    save: (_publication, _mode, capability) => { value = capability; },
    clear: () => { value = null; },
    current: () => value,
  };
}

test("machine starts and resumes the same opaque session", async () => {
  const store = capabilityStore();
  let resumes = 0;
  const client = {
    start: async () => ({ capability: "cap-1", session: session() }),
    resume: async () => { resumes += 1; return session(); },
  };
  const first = new DailyReelMachine({ client, capabilities: store, publicationId: "2026-08-28", locale: "en" });
  await first.load();
  assert.equal(first.state.phase, "playing");
  assert.equal(store.current(), "cap-1");

  const second = new DailyReelMachine({ client, capabilities: store, publicationId: "2026-08-28", locale: "en" });
  await second.load();
  assert.equal(resumes, 1);
});

test("explicit retry preserves the original idempotency key", async () => {
  const requests = [];
  let fail = true;
  const client = {
    start: async () => ({ capability: "cap-1", session: session() }),
    submitAttempt: async (request) => {
      requests.push(request.requestId);
      if (fail) throw new DailyReelClientError("temporary", "retry", 503);
      return { correct: true, session: session({ sequence: 1, currentActIndex: 1 }) };
    },
  };
  const machine = new DailyReelMachine({
    client,
    capabilities: capabilityStore(),
    publicationId: "2026-08-28",
    locale: "en",
    requestId: () => "request-12345678",
  });
  await machine.load();
  await machine.submit("Titanic");
  assert.equal(machine.state.canRetry, true);
  fail = false;
  await machine.retry();
  assert.deepEqual(requests, ["request-12345678", "request-12345678"]);
});

test("stale sequence reconciles from the authoritative session", async () => {
  let resumes = 0;
  const client = {
    start: async () => ({ capability: "cap-1", session: session() }),
    submitAttempt: async () => { throw new DailyReelClientError("session.stale_sequence", "refresh", 409); },
    resume: async () => { resumes += 1; return session({ sequence: 2, currentActIndex: 1 }); },
  };
  const machine = new DailyReelMachine({ client, capabilities: capabilityStore(), publicationId: "2026-08-28", locale: "en" });
  await machine.load();
  await machine.submit("Titanic");
  assert.equal(resumes, 1);
  assert.equal(machine.state.session.sequence, 2);
  assert.equal(machine.state.canRetry, false);
});

test("machine normalizes the authoritative server projection for the play UI", async () => {
  const client = {
    start: async () => ({
      capability: "cap-1",
      session: session({
        configId: "server-config",
        currentAct: {
          id: "connect-1",
          role: "connect",
          choices: [{ id: "c1", label: "Directed by Steven Spielberg" }],
          films: [{ id: "tmdb:329", title: "Jurassic Park", posterPath: null }],
        },
        acts: [{
          actId: "connect-1",
          role: "connect",
          status: "playing",
          incorrectAttempts: 0,
          scoreAffectingClues: 0,
          requestedClueIds: [],
          score: null,
        }],
      }),
    }),
  };
  const machine = new DailyReelMachine({ client, capabilities: capabilityStore(), publicationId: "2026-08-28", locale: "en" });
  await machine.load();
  assert.deepEqual(machine.state.session.currentAct.options, [{ id: "c1", label: "Directed by Steven Spielberg" }]);
  assert.equal(machine.state.session.currentProgress.actId, "connect-1");
});

test("machine preserves the solved-act explanation when play advances", async () => {
  const client = {
    start: async () => ({ capability: "cap-1", session: session() }),
    submitAttempt: async () => ({
      correct: true,
      reveal: {
        role: "decode",
        title: "Back to the Future",
        explanation: "The symbols point to reversing time, a car, and lightning.",
      },
      session: session({
        sequence: 1,
        currentActIndex: 1,
        currentAct: { id: "connect", role: "connect" },
      }),
    }),
  };
  const machine = new DailyReelMachine({ client, capabilities: capabilityStore(), publicationId: "2026-08-28", locale: "en" });
  await machine.load();
  await machine.submit("Back to the Future");
  assert.deepEqual(machine.state.feedback, {
    type: "correct",
    role: "decode",
    answer: "Back to the Future",
    text: "The symbols point to reversing time, a car, and lightning.",
    advanced: true,
  });
});

test("machine preserves the completion-only thread through the final mutation", async () => {
  const arrangeSession = session({
    currentActIndex: 2,
    currentAct: { id: "arrange", role: "arrange" },
  });
  const client = {
    start: async () => ({ capability: "cap-1", session: arrangeSession }),
    submitAttempt: async () => ({
      correct: true,
      reveal: {
        role: "arrange",
        title: "Three eras of the Bat",
        explanation: "Batman opened in 1989, 2005, and 2022.",
        threadTitle: "Three eras of the Bat",
        threadExplanation: "Christopher Nolan carries the reel from The Dark Knight into three generations of Gotham.",
      },
      session: session({
        status: "completed",
        sequence: 1,
        currentActIndex: 3,
        currentAct: null,
        completedAt: "2026-09-01T12:00:00.000Z",
      }),
    }),
  };
  const machine = new DailyReelMachine({ client, capabilities: capabilityStore(), publicationId: "2026-09-01", locale: "en" });
  await machine.load();
  await machine.submit(["tmdb:268", "tmdb:272", "tmdb:414906"]);

  assert.equal(machine.state.feedback.threadTitle, "Three eras of the Bat");
  assert.equal(
    machine.state.feedback.threadExplanation,
    "Christopher Nolan carries the reel from The Dark Knight into three generations of Gotham.",
  );
});

test("machine builds a useful reveal when an older server omits it", async () => {
  const client = {
    start: async () => ({
      capability: "cap-1",
      session: session({ currentAct: { id: "decode", role: "decode", emoji: ["⏪", "🚗", "⚡"] } }),
    }),
    submitAttempt: async () => ({
      correct: true,
      reveal: null,
      session: session({ sequence: 1, currentActIndex: 1, currentAct: { id: "connect", role: "connect" } }),
    }),
  };
  const machine = new DailyReelMachine({ client, capabilities: capabilityStore(), publicationId: "2026-08-28", locale: "en" });
  await machine.load();
  await machine.submit("Back to the Future");
  assert.equal(machine.state.feedback.answer, "Back to the Future");
  assert.equal(machine.state.feedback.text, "⏪ + 🚗 + ⚡ resolves to Back to the Future.");
  assert.equal(machine.state.feedback.advanced, true);
});

test("title-length assistance produces a useful clue instead of placeholder copy", async () => {
  const client = {
    start: async () => ({ capability: "cap-1", session: session() }),
    requestAssist: async () => ({
      correct: null,
      reveal: null,
      assist: { id: "title-length", kind: "titleLength", titleLength: 15 },
      session: session({ sequence: 1 }),
    }),
  };
  const machine = new DailyReelMachine({ client, capabilities: capabilityStore(), publicationId: "2026-08-28", locale: "en" });
  await machine.load();
  await machine.assist("titleLength");
  assert.equal(machine.state.feedback.text, "15 characters in the title.");
});

test("incorrect answers coach the current act instead of returning generic copy", async () => {
  const connectSession = session({ currentActIndex: 1, currentAct: { id: "connect", role: "connect", films: [{}, {}, {}] } });
  const client = {
    start: async () => ({ capability: "cap-1", session: connectSession }),
    submitAttempt: async () => ({
      correct: false,
      reveal: null,
      session: { ...connectSession, sequence: 1 },
    }),
  };
  const machine = new DailyReelMachine({ client, capabilities: capabilityStore(), publicationId: "2026-08-28", locale: "en" });
  await machine.load();
  await machine.submit("wrong-choice");
  assert.equal(machine.state.feedback.text, "One frame breaks that connection. Test the choice against all three movies.");
});

test("single-film Connect coaching never invents three movies", async () => {
  const connectSession = session({ currentActIndex: 1, currentAct: { id: "connect", role: "connect", films: [] } });
  const client = {
    start: async () => ({ capability: "cap-1", session: connectSession }),
    submitAttempt: async () => ({ correct: false, reveal: null, session: { ...connectSession, sequence: 1 } }),
  };
  const machine = new DailyReelMachine({ client, capabilities: capabilityStore(), publicationId: "2026-08-30", locale: "en" });
  await machine.load();
  await machine.submit("2004");
  assert.equal(machine.state.feedback.text, "That detail does not fit this movie. Recheck the release clue and try another cut.");
});

test("App Check startup failures expose a recoverable practice path", async () => {
  const error = Object.assign(new Error("secure check failed"), {
    code: "app_check.unavailable",
    providerCode: "appCheck/initial-throttle",
  });
  const events = [];
  const machine = new DailyReelMachine({
    client: { start: async () => { throw error; } },
    capabilities: capabilityStore(),
    publicationId: "2026-08-30",
    locale: "en-US",
    track: (event, properties) => events.push({ event, properties }),
  });

  await machine.load();

  assert.equal(machine.state.phase, "failed");
  assert.equal(machine.state.errorCode, "app_check.unavailable");
  assert.equal(machine.state.recoveryKind, "app_check");
  assert.equal(machine.state.canRetry, true);
  assert.deepEqual(events.at(-1), {
    event: "daily_reel_failed",
    properties: {
      error_code: "app_check.unavailable",
      provider_code: "appCheck/initial-throttle",
      recovery_kind: "app_check",
    },
  });
});
