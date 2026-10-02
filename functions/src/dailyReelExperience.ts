import { createHash } from "node:crypto";
import {
  DAILY_REEL_EXPERIENCE_VERSION,
  DAILY_REEL_SCORING_VERSION,
  DailyReelExperienceConfigSchema,
  type DailyReelExperienceConfig,
} from "./dailyReelSchema.js";

export const DAILY_REEL_FLAG_KEYS = {
  rollout: "daily-reel-rollout",
  assistance: "daily-reel-assistance",
  results: "daily-reel-results",
} as const;

export type DailyReelAssignmentSource = "posthog" | "cache" | "challenge";

export interface DailyReelRawFlag {
  enabled: boolean;
  variant?: string | null;
  payload?: unknown;
}

export type DailyReelRawFlags = Record<string, DailyReelRawFlag | boolean | string | null | undefined>;

export interface DailyReelFlagProvider {
  flagsFor(distinctId: string): Promise<DailyReelRawFlags>;
}

export interface DailyReelExperienceResolution {
  eligible: boolean;
  config: DailyReelExperienceConfig | null;
  configId: string | null;
  assignmentSource: DailyReelAssignmentSource | null;
  variants: Record<string, string>;
}

export interface DailyReelExperienceCache {
  get(distinctId: string): DailyReelExperienceResolution | null;
  set(distinctId: string, resolution: DailyReelExperienceResolution): void;
}

export class InMemoryDailyReelExperienceCache implements DailyReelExperienceCache {
  private readonly values = new Map<string, DailyReelExperienceResolution>();

  get(distinctId: string): DailyReelExperienceResolution | null {
    const value = this.values.get(distinctId);
    return value ? clone(value) : null;
  }

  set(distinctId: string, resolution: DailyReelExperienceResolution): void {
    this.values.set(distinctId, clone(resolution));
  }
}

export class DailyReelExperienceResolver {
  constructor(
    private readonly provider: DailyReelFlagProvider,
    private readonly cache: DailyReelExperienceCache = new InMemoryDailyReelExperienceCache(),
  ) {}

  async resolve(distinctId: string): Promise<DailyReelExperienceResolution> {
    try {
      const flags = await this.provider.flagsFor(distinctId);
      const resolution = resolveFlags(flags);
      this.cache.set(distinctId, resolution);
      return resolution;
    } catch {
      const cached = this.cache.get(distinctId);
      if (cached?.eligible && cached.config) {
        return { ...cached, assignmentSource: "cache" };
      }
      return ineligible();
    }
  }

  resolveFrozen(configInput: unknown): DailyReelExperienceResolution {
    const parsed = DailyReelExperienceConfigSchema.parse(configInput);
    return {
      eligible: true,
      config: parsed,
      configId: parsed.configId,
      assignmentSource: "challenge",
      variants: {},
    };
  }
}

export function baselineDailyReelExperienceConfig(input: {
  titleLengthEnabled?: boolean;
  standardHintEnabled?: boolean;
  pickTonightEnabled?: boolean;
} = {}): DailyReelExperienceConfig {
  const settings = {
    configVersion: DAILY_REEL_EXPERIENCE_VERSION,
    scoringVersion: DAILY_REEL_SCORING_VERSION,
    maxIncorrectAttemptsPerAct: 3 as const,
    actOrder: ["decode", "connect", "arrange"] as const,
    assistance: {
      titleLength: { enabled: input.titleLengthEnabled ?? true, scoreImpact: 0 as const },
      standardHint: { enabled: input.standardHintEnabled ?? true, scoreImpact: 1 as const },
    },
    results: {
      rematchProminence: "primary" as const,
      pickTonightEnabled: input.pickTonightEnabled ?? true,
    },
    festival: {
      targetDistinctReels: 5 as const,
      encoreRewardCount: 1 as const,
    },
  };
  const configId = `reel-config-${createHash("sha256")
    .update(JSON.stringify(settings))
    .digest("hex")
    .slice(0, 16)}`;
  return DailyReelExperienceConfigSchema.parse({ ...settings, configId });
}

function resolveFlags(flags: DailyReelRawFlags): DailyReelExperienceResolution {
  const rollout = normalizeFlag(flags[DAILY_REEL_FLAG_KEYS.rollout]);
  if (!rollout.enabled) return ineligible();

  const assistance = normalizeFlag(flags[DAILY_REEL_FLAG_KEYS.assistance]);
  const results = normalizeFlag(flags[DAILY_REEL_FLAG_KEYS.results]);
  const assistancePayload = asRecord(assistance.payload);
  const resultsPayload = asRecord(results.payload);
  const config = baselineDailyReelExperienceConfig({
    titleLengthEnabled: booleanOrDefault(assistancePayload.titleLengthEnabled, true),
    standardHintEnabled: booleanOrDefault(assistancePayload.standardHintEnabled, true),
    pickTonightEnabled: booleanOrDefault(resultsPayload.pickTonightEnabled, true),
  });
  const variants = Object.fromEntries(
    [
      [DAILY_REEL_FLAG_KEYS.rollout, rollout.variant],
      [DAILY_REEL_FLAG_KEYS.assistance, assistance.variant],
      [DAILY_REEL_FLAG_KEYS.results, results.variant],
    ].filter((entry): entry is [string, string] => Boolean(entry[1])),
  );
  return {
    eligible: true,
    config,
    configId: config.configId,
    assignmentSource: "posthog",
    variants,
  };
}

function normalizeFlag(value: DailyReelRawFlags[string]): DailyReelRawFlag {
  if (typeof value === "boolean") return { enabled: value };
  if (typeof value === "string") {
    return { enabled: value === "baseline" || value === "reel" || value === "enhanced", variant: value };
  }
  if (value && typeof value === "object" && typeof value.enabled === "boolean") {
    return value;
  }
  return { enabled: false };
}

function asRecord(value: unknown): Record<string, unknown> {
  return value && typeof value === "object" && !Array.isArray(value)
    ? (value as Record<string, unknown>)
    : {};
}

function booleanOrDefault(value: unknown, fallback: boolean): boolean {
  return typeof value === "boolean" ? value : fallback;
}

function ineligible(): DailyReelExperienceResolution {
  return {
    eligible: false,
    config: null,
    configId: null,
    assignmentSource: null,
    variants: {},
  };
}

function clone<T>(value: T): T {
  return JSON.parse(JSON.stringify(value)) as T;
}
