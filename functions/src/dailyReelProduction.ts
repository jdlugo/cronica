import { getAppCheck } from "firebase-admin/app-check";
import type { Firestore } from "firebase-admin/firestore";
import { DailyReelChallengeHandlers } from "./dailyReelChallengeHandlers.js";
import { DailyReelChallengeService, FirestoreDailyReelChallengeStore } from "./dailyReelChallenges.js";
import { InMemoryDailyReelExperienceCache, DailyReelExperienceResolver } from "./dailyReelExperience.js";
import { FirebaseAdminDailyReelAppCheckVerifier } from "./dailyReelFirebaseAppCheck.js";
import { DailyReelHTTPAPI } from "./dailyReelHTTPAPI.js";
import { PostHogDailyReelFlagProvider } from "./dailyReelPostHog.js";
import { DailyReelRequestGuard, FirestoreDailyReelRateLimitStore } from "./dailyReelRequestGuards.js";
import { DailyReelSecurity } from "./dailyReelSecurity.js";
import { SessionBackedDailyReelChallengeGateway } from "./dailyReelSessionChallengeGateway.js";
import {
  DailyReelSessionService,
  FirestoreDailyReelContentStore,
  FirestoreDailyReelSessionStore,
} from "./dailyReelSessions.js";

export function makeProductionDailyReelAPI(input: {
  firestore: Firestore;
  capabilitySecret: string;
  posthogProjectToken: string;
  shareBaseUrl: string;
  allowedAppIds: ReadonlySet<string>;
  onInternalError?: (error: unknown) => void;
}) {
  const security = new DailyReelSecurity(input.capabilitySecret);
  const sessionStore = new FirestoreDailyReelSessionStore(input.firestore);
  const experience = new DailyReelExperienceResolver(
    new PostHogDailyReelFlagProvider(input.posthogProjectToken),
    new InMemoryDailyReelExperienceCache(),
  );
  const sessions = new DailyReelSessionService(
    sessionStore,
    new FirestoreDailyReelContentStore(input.firestore),
    experience,
    security,
  );
  const guard = new DailyReelRequestGuard(
    new FirebaseAdminDailyReelAppCheckVerifier(getAppCheck()),
    new FirestoreDailyReelRateLimitStore(input.firestore),
    security,
    input.allowedAppIds,
  );
  const challenges = new DailyReelChallengeService(
    new FirestoreDailyReelChallengeStore(input.firestore),
    new SessionBackedDailyReelChallengeGateway(sessionStore, sessions, security),
    security,
    input.shareBaseUrl,
  );
  return new DailyReelHTTPAPI(
    sessions,
    new DailyReelChallengeHandlers(challenges, guard),
    guard,
    input.onInternalError,
  );
}
