export class DailyReelClientError extends Error {
  constructor(code, message, statusCode = 0) {
    super(message);
    this.code = code;
    this.statusCode = statusCode;
  }
}

export class LiveDailyReelClient {
  constructor({ baseUrl, appCheckToken, identity, fetchImpl = (...args) => globalThis.fetch(...args) }) {
    if (!baseUrl) throw new Error("Daily Reel API base URL is required");
    this.baseUrl = new URL(baseUrl);
    this.appCheckToken = appCheckToken;
    this.identity = identity;
    this.fetchImpl = fetchImpl;
  }

  async start({ publicationId, locale, mode = "daily", scopeId = null }) {
    return this.#post("daily-reel/session/start", {
      anonymousId: await this.identity.get(),
      publicationId,
      locale,
      mode,
      scopeId,
    });
  }

  async resume(capability) {
    const response = await this.#post("daily-reel/session/resume", { capability });
    return response.session;
  }

  submitAttempt({ capability, expectedSequence, requestId, answer }) {
    return this.#post("daily-reel/session/attempt", {
      capability,
      expectedSequence,
      requestId,
      answer,
    });
  }

  requestAssist({ capability, expectedSequence, requestId, kind }) {
    return this.#post("daily-reel/session/assist", {
      capability,
      expectedSequence,
      requestId,
      kind,
    });
  }

  reveal({ capability, expectedSequence, requestId }) {
    return this.#post("daily-reel/session/reveal", {
      capability,
      expectedSequence,
      requestId,
    });
  }

  createChallenge({ sourceSessionCapability, requestId, nickname }) {
    return this.#post("daily-reel/challenge/create", {
      anonymousId: this.identity.getSync?.() ?? undefined,
      sourceSessionCapability,
      requestId,
      nickname,
    }, true);
  }

  async claimChallenge(capability) {
    return this.#post("daily-reel/challenge/claim", {
      anonymousId: await this.identity.get(),
      capability,
    });
  }

  async #post(path, body) {
    const payload = { ...body };
    if (!payload.anonymousId) payload.anonymousId = await this.identity.get();
    const url = new URL(path, this.baseUrl);
    const response = await this.fetchImpl(url, {
      method: "POST",
      headers: {
        "Accept": "application/json",
        "Content-Type": "application/json",
        "X-Firebase-AppCheck": await this.appCheckToken(),
      },
      body: JSON.stringify(payload),
    });
    const data = await response.json().catch(() => ({}));
    if (!response.ok) {
      throw new DailyReelClientError(
        data.code || `http_${response.status}`,
        data.message || "Daily Reel request failed",
        response.status,
      );
    }
    return data;
  }
}

export function createBrowserIdentity(storage = globalThis.localStorage) {
  const key = "dailyReel.anonymousInstallationId";
  let cached = storage?.getItem(key) || null;
  return {
    async get() {
      if (!cached) {
        cached = globalThis.crypto.randomUUID().toLowerCase();
        storage?.setItem(key, cached);
      }
      return cached;
    },
    getSync() { return cached; },
  };
}

export function createCapabilityStore(storage = globalThis.sessionStorage) {
  const key = (publicationId, mode, scopeId = null) => [
    "dailyReel.capability",
    mode,
    publicationId,
    scopeId || "default",
  ].join(".");
  return {
    load(publicationId, mode, scopeId = null) {
      return storage?.getItem(key(publicationId, mode, scopeId)) || null;
    },
    save(publicationId, mode, capability, scopeId = null) {
      storage?.setItem(key(publicationId, mode, scopeId), capability);
    },
    clear(publicationId, mode, scopeId = null) {
      storage?.removeItem(key(publicationId, mode, scopeId));
    },
  };
}

export function consumeChallengeCapability(location = globalThis.location, history = globalThis.history) {
  const fragment = new URLSearchParams(location.hash.replace(/^#/, ""));
  const capability = fragment.get("capability");
  if (capability && history?.replaceState) {
    history.replaceState(null, "", `${location.pathname}${location.search}`);
  }
  return capability;
}
