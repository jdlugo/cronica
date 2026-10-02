import type { DailyReelFlagProvider, DailyReelRawFlags } from "./dailyReelExperience.js";

type FetchLike = typeof fetch;

export class PostHogDailyReelFlagProvider implements DailyReelFlagProvider {
  constructor(
    private readonly projectToken: string,
    private readonly host = "https://us.i.posthog.com",
    private readonly fetcher: FetchLike = fetch,
  ) {}

  async flagsFor(distinctId: string): Promise<DailyReelRawFlags> {
    if (!this.projectToken) throw new Error("PostHog project token is required");
    const response = await this.fetcher(`${this.host.replace(/\/$/, "")}/flags/?v=2`, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ api_key: this.projectToken, distinct_id: distinctId }),
      signal: AbortSignal.timeout(5_000),
    });
    if (!response.ok) throw new Error(`PostHog flags request failed with ${response.status}`);
    const payload = await response.json() as {
      flags?: Record<string, unknown>;
      featureFlags?: Record<string, unknown>;
      featureFlagPayloads?: Record<string, unknown>;
    };
    const raw = payload.flags ?? payload.featureFlags ?? {};
    return Object.fromEntries(Object.entries(raw).map(([key, value]) => [
      key,
      normalizeFlag(value, payload.featureFlagPayloads?.[key]),
    ]));
  }
}

function normalizeFlag(value: unknown, legacyPayload: unknown): DailyReelRawFlags[string] {
  if (typeof value === "boolean" || typeof value === "string" || value === null) return value;
  if (!value || typeof value !== "object") return null;
  const object = value as Record<string, unknown>;
  const variant = typeof object.variant === "string" ? object.variant : null;
  const enabled = typeof object.enabled === "boolean" ? object.enabled : Boolean(variant);
  const metadata = object.metadata && typeof object.metadata === "object"
    ? object.metadata as Record<string, unknown>
    : {};
  return {
    enabled,
    variant,
    payload: object.payload ?? metadata.payload ?? legacyPayload,
  };
}
