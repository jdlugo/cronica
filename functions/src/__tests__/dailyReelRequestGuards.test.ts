import { describe, expect, it } from "vitest";
import { DailyReelSecurity } from "../dailyReelSecurity.js";
import {
  DAILY_REEL_RATE_LIMITS,
  DailyReelRequestGuard,
  InMemoryDailyReelRateLimitStore,
  type DailyReelAppCheckVerifier,
} from "../dailyReelRequestGuards.js";

class FakeVerifier implements DailyReelAppCheckVerifier {
  async verify(token: string) {
    if (token === "invalid") throw new Error("invalid");
    return { appId: token === "wrong-app" ? "other.app" : "com.dlugokecki.qscanlite" };
  }
}

function setup() {
  let now = 1_800_000_000_000;
  const guard = new DailyReelRequestGuard(
    new FakeVerifier(),
    new InMemoryDailyReelRateLimitStore(),
    new DailyReelSecurity("daily-reel-unit-test-secret-with-32-bytes"),
    new Set(["com.dlugokecki.qscanlite"]),
    () => now,
  );
  return { guard, advance: (milliseconds: number) => { now += milliseconds; } };
}

describe("DailyReelRequestGuard", () => {
  it("fails closed without valid App Check", async () => {
    const { guard } = setup();
    await expect(guard.authorize({ route: "session.start", appCheckToken: "", anonymousId: "install-a" }))
      .rejects.toMatchObject({ code: "app_check.required" });
    await expect(guard.authorize({ route: "session.start", appCheckToken: "invalid", anonymousId: "install-a" }))
      .rejects.toMatchObject({ code: "app_check.invalid" });
    await expect(guard.authorize({ route: "session.start", appCheckToken: "wrong-app", anonymousId: "install-a" }))
      .rejects.toMatchObject({ code: "app_check.wrong_app" });
  });

  it("enforces independent per-route and per-installation windows", async () => {
    const { guard } = setup();
    const limit = DAILY_REEL_RATE_LIMITS["challenge.create"].limit;
    for (let index = 0; index < limit; index += 1) {
      await guard.authorize({ route: "challenge.create", appCheckToken: "valid", anonymousId: "install-a" });
    }
    await expect(guard.authorize({ route: "challenge.create", appCheckToken: "valid", anonymousId: "install-a" }))
      .rejects.toMatchObject({ code: "rate_limit.exceeded" });
    await expect(guard.authorize({ route: "challenge.read", appCheckToken: "valid", anonymousId: "install-a" }))
      .resolves.toMatchObject({ appId: "com.dlugokecki.qscanlite" });
    await expect(guard.authorize({ route: "challenge.create", appCheckToken: "valid", anonymousId: "install-b" }))
      .resolves.toMatchObject({ remaining: limit - 1 });
  });

  it("resets a limit after its fixed window", async () => {
    const { guard, advance } = setup();
    const policy = DAILY_REEL_RATE_LIMITS["challenge.create"];
    for (let index = 0; index < policy.limit; index += 1) {
      await guard.authorize({ route: "challenge.create", appCheckToken: "valid", anonymousId: "install-a" });
    }
    advance(policy.windowMs);
    await expect(guard.authorize({ route: "challenge.create", appCheckToken: "valid", anonymousId: "install-a" }))
      .resolves.toMatchObject({ remaining: policy.limit - 1 });
  });
});
