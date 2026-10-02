const acts = [
  {
    id: "decode",
    role: "decode",
    title: "Name the movie",
    prompt: "Turn the visual clue into a title.",
    emojis: ["🚢", "🧊", "❤️"],
  },
  {
    id: "connect",
    role: "connect",
    title: "Find the connection",
    prompt: "Which year connects the film to its theatrical release?",
    options: [
      { id: "1997", label: "1997" },
      { id: "2004", label: "2004" },
      { id: "1985", label: "1985" },
    ],
  },
  {
    id: "arrange",
    role: "arrange",
    title: "Cut it in order",
    prompt: "Put these story beats into the order they appear.",
    items: [
      { id: "iceberg", label: "The iceberg is spotted" },
      { id: "boarding", label: "Passengers board the ship" },
      { id: "necklace", label: "The necklace is dropped" },
    ],
  },
];

const answers = ["titanic", "1997", ["boarding", "iceberg", "necklace"]];
const reveals = [
  { role: "decode", title: "Titanic", explanation: "The ship, iceberg, and love story reveal Titanic." },
  { role: "connect", explanation: "Titanic opened in theaters in 1997." },
  { role: "arrange", explanation: "Passengers board, the iceberg is spotted, and the necklace is dropped last." },
];

export class DemoDailyReelClient {
  constructor() {
    this.sequence = 0;
    this.index = 0;
    this.score = 3000;
    this.progress = acts.map((act) => ({
      actId: act.id,
      role: act.role,
      status: "active",
      attempts: 0,
      usedFreeClue: false,
      usedScoreHint: false,
    }));
  }

  async start({ publicationId, locale, mode }) {
    this.publicationId = publicationId;
    this.locale = locale;
    this.mode = mode;
    const capability = [
      "preview-session-capability",
      mode || "daily",
      publicationId,
      encodeURIComponent(locale || "en"),
    ].join(":");
    return { capability, session: this.#session() };
  }

  async resume(capability) {
    const [prefix, mode, publicationId, locale] = String(capability || "").split(":");
    if (prefix === "preview-session-capability") {
      this.mode = ["daily", "practice", "encore"].includes(mode) ? mode : "daily";
      this.publicationId = publicationId || this.publicationId;
      this.locale = locale ? decodeURIComponent(locale) : this.locale;
    }
    return this.#session();
  }

  async submitAttempt({ answer }) {
    const actIndex = this.index;
    const correct = matches(answer, answers[actIndex]);
    this.progress[actIndex].attempts += 1;
    this.sequence += 1;
    const terminal = correct || this.progress[actIndex].attempts >= 3;
    if (terminal) {
      if (!correct) this.score -= 350;
      this.progress[actIndex].status = correct ? "solved" : "revealed";
      this.index += 1;
    } else {
      this.score -= 100;
    }
    return { correct, reveal: terminal ? reveals[actIndex] : null, session: this.#session() };
  }

  async requestAssist({ kind }) {
    const progress = this.progress[this.index];
    if (kind === "titleLength") progress.usedFreeClue = true;
    if (kind === "hint") {
      progress.usedScoreHint = true;
      this.score -= 150;
    }
    this.sequence += 1;
    const assists = [
      kind === "titleLength" ? { kind, titleLength: 7 } : { kind, text: "James Cameron directed it." },
      { kind, text: "It premiered before the turn of the century." },
      { kind, text: "The necklace has the final beat." },
    ];
    return { assist: assists[this.index], session: this.#session() };
  }

  async reveal() {
    const actIndex = this.index;
    this.progress[actIndex].status = "revealed";
    this.score -= 400;
    this.sequence += 1;
    this.index += 1;
    return { correct: false, reveal: reveals[actIndex], session: this.#session() };
  }

  async createChallenge() {
    return { shareUrl: `${location.origin}/c#capability=preview-friend-challenge` };
  }

  #session() {
    const complete = this.index >= acts.length;
    const currentAct = complete ? null : acts[this.index];
    return structuredClone({
      sessionId: "preview-session",
      publicationId: this.publicationId || new Date().toISOString().slice(0, 10),
      versionId: "preview-v1",
      locale: this.locale || "en",
      mode: this.mode || "daily",
      assignmentSource: "preview",
      experienceConfig: { actCount: 3, assistance: "baseline", resultStyle: "festival" },
      configId: "preview-config",
      sequence: this.sequence,
      currentActIndex: this.index,
      currentAct,
      currentProgress: complete ? null : this.progress[this.index],
      totalScore: complete ? Math.max(0, this.score) : null,
      completedAt: complete ? Date.now() : null,
      expiresAt: Date.now() + 86_400_000,
    });
  }
}

function matches(actual, expected) {
  if (Array.isArray(expected)) return JSON.stringify(actual) === JSON.stringify(expected);
  return String(actual).trim().toLowerCase() === expected;
}
