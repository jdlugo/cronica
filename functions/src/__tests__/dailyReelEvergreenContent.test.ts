import { describe, expect, it } from "vitest";
import { rebaseEvergreenDailyReelContent } from "../dailyReelSessions.js";
import { makePrivateReel } from "./dailyReelTestFixtures.js";

describe("evergreen Daily Reel content", () => {
  it("rebases the public identity and 24-hour window without mutating the approved version", () => {
    const original = {
      publicationId: "2026-08-30",
      versionId: "daily-reel-2026-08-30.1",
      privateReel: makePrivateReel(),
    };

    const rebased = rebaseEvergreenDailyReelContent(original, "2026-08-31");

    expect(rebased.publicationId).toBe("2026-08-31");
    expect(rebased.versionId).toBe(original.versionId);
    expect(rebased.privateReel.reel.publicationId).toBe("2026-08-31");
    expect(rebased.privateReel.reel.publicationWindow).toEqual({
      availableAt: "2026-08-31T05:00:00.000Z",
      expiresAt: "2026-09-01T05:00:00.000Z",
    });
    expect(original.publicationId).toBe("2026-08-30");
    expect(original.privateReel.reel.publicationId).not.toBe("2026-08-31");
  });
});
