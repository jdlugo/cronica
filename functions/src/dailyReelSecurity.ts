import { createHash, createHmac } from "node:crypto";

export class DailyReelSecurity {
  constructor(private readonly secret: string) {
    if (Buffer.byteLength(secret, "utf8") < 32) {
      throw new Error("Daily Reel capability secret must be at least 32 bytes");
    }
  }

  hashAnonymousId(anonymousId: string): string {
    const normalized = anonymousId.trim();
    if (!normalized) throw new Error("Anonymous installation ID is required");
    return this.hmac(`anonymous\u0000${normalized}`);
  }

  deriveSessionCapability(input: {
    anonymousIdHash: string;
    publicationId: string;
    mode: string;
    scopeId?: string;
  }): string {
    return this.hmac([
      "session-capability.v1",
      input.anonymousIdHash,
      input.publicationId,
      input.mode,
      input.scopeId ?? "default",
    ].join("\u0000"));
  }

  deriveChallengeCapability(input: {
    sessionId: string;
    requestId: string;
  }): string {
    return this.hmac([
      "challenge-capability.v1",
      input.sessionId,
      input.requestId,
    ].join("\u0000"));
  }

  hashCapability(capability: string): string {
    const normalized = capability.trim();
    if (!normalized) throw new Error("Capability is required");
    return createHash("sha256").update(normalized).digest("hex");
  }

  private hmac(value: string): string {
    return createHmac("sha256", this.secret).update(value).digest("base64url");
  }
}
