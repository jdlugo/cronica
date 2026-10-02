export class PostHogBridge {
  constructor({ projectToken, host = "https://us.i.posthog.com", distinctId, fetchImpl = (...args) => globalThis.fetch(...args) }) {
    this.projectToken = projectToken;
    this.host = host.replace(/\/$/, "");
    this.distinctId = distinctId;
    this.fetchImpl = fetchImpl;
    this.flags = null;
  }

  async featureFlag(key) {
    if (!this.projectToken || !this.distinctId) return false;
    if (!this.flags) {
      try {
        const response = await this.fetchImpl(`${this.host}/flags/?v=2`, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ api_key: this.projectToken, distinct_id: this.distinctId }),
        });
        if (!response.ok) return false;
        const payload = await response.json();
        this.flags = payload.flags || payload.featureFlags || {};
      } catch {
        return false;
      }
    }
    const value = this.flags[key];
    if (value && typeof value === "object") return value.variant ?? value.enabled ?? false;
    return value ?? false;
  }

  capture(event, properties = {}) {
    if (!this.projectToken || !this.distinctId) return;
    const body = {
      api_key: this.projectToken,
      event,
      properties: {
        ...properties,
        distinct_id: this.distinctId,
        surface: "web",
      },
      timestamp: new Date().toISOString(),
    };
    this.fetchImpl(`${this.host}/i/v0/e/`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(body),
      keepalive: true,
    }).catch(() => {});
  }
}

export function isDailyReelRolloutEnabled(value, publicLaunch = false) {
  if (publicLaunch) return true;
  if (value === true) return true;
  if (typeof value !== "string") return false;
  return !["", "false", "disabled", "off", "none"].includes(value.trim().toLowerCase());
}
