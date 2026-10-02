import type { AppCheck } from "firebase-admin/app-check";
import type { DailyReelAppCheckVerifier } from "./dailyReelRequestGuards.js";

export class FirebaseAdminDailyReelAppCheckVerifier implements DailyReelAppCheckVerifier {
  constructor(private readonly appCheck: AppCheck) {}

  async verify(token: string) {
    const decoded = await this.appCheck.verifyToken(token);
    return { appId: decoded.appId };
  }
}
