import assert from "node:assert/strict";
import test from "node:test";
import { DailyReelMachine } from "../src/daily-reel-machine.js";

test("claimed challenge resumes without exposing the invite capability", async () => {
  const calls = [];
  const stored = [];
  const client = {
    async claimChallenge(capability) {
      calls.push(["claim", capability]);
      return {
        sessionCapability: "session-secret",
        challenge: { publicationId: "2026-08-28", locale: "en-US" },
      };
    },
    async resume(capability) {
      calls.push(["resume", capability]);
      return {
        publicationId: "2026-08-28",
        locale: "en-US",
        mode: "challenge",
        currentActIndex: 0,
        currentAct: { id: "decode", role: "decode", emoji: ["x"] },
        acts: [{ actId: "decode", role: "decode", status: "playing" }],
        sequence: 0,
        totalScore: 0,
        completedAt: null,
      };
    },
  };
  const capabilities = {
    load() { return null; },
    save(publicationId, mode, capability) { stored.push({ publicationId, mode, capability }); },
    clear() {},
  };
  const events = [];
  const machine = new DailyReelMachine({
    client,
    capabilities,
    publicationId: "placeholder",
    locale: "en",
    track: (event, properties) => events.push({ event, properties }),
  });

  await machine.claimChallenge("invite-secret");

  assert.deepEqual(calls, [
    ["claim", "invite-secret"],
    ["resume", "session-secret"],
  ]);
  assert.deepEqual(stored, [{ publicationId: "2026-08-28", mode: "challenge", capability: "session-secret" }]);
  assert.equal(machine.state.phase, "playing");
  assert.equal(machine.state.capability, "session-secret");
  assert.equal(events[0].event, "daily_reel_challenge_claimed");
  assert.equal(JSON.stringify(events).includes("invite-secret"), false);
  assert.equal(JSON.stringify(events).includes("session-secret"), false);
});
