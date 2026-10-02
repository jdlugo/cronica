export interface DailyPuzzleAdminConfig {
  enabled: boolean;
  pushEnabled: boolean;
}

export function normalizeDailyPuzzleAdminConfig(raw: unknown): DailyPuzzleAdminConfig {
  const source = (raw ?? {}) as Record<string, unknown>;
  return {
    enabled: source.enabled === false ? false : true,
    pushEnabled: source.pushEnabled === false ? false : true
  };
}
