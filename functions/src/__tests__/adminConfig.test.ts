import { describe, expect, it } from "vitest";

import { normalizeDailyPuzzleAdminConfig } from "../adminConfig.js";

describe("daily puzzle admin config", () => {
  it("defaults both generation and push to enabled", () => {
    const config = normalizeDailyPuzzleAdminConfig(undefined);
    expect(config.enabled).toBe(true);
    expect(config.pushEnabled).toBe(true);
  });

  it("respects explicit disable values from firestore", () => {
    const config = normalizeDailyPuzzleAdminConfig({ enabled: false, pushEnabled: false });
    expect(config.enabled).toBe(false);
    expect(config.pushEnabled).toBe(false);
  });
});
