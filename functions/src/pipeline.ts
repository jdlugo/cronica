import type { DailyPuzzleAdminConfig } from "./adminConfig.js";
import { runGenerateDailyPuzzleTask, type DailyPuzzlePushPayload } from "./handlers.js";
import type { DailyPuzzleDocument } from "./puzzleSchema.js";

interface LoggerLike {
  info: (message: string, metadata?: unknown) => void;
  error: (message: string, metadata?: unknown) => void;
}

interface RunDailyPuzzlePipelineInput {
  targetDate: Date;
  loadAdminConfig: () => Promise<DailyPuzzleAdminConfig>;
  loadExistingPuzzle?: (targetDate: Date) => Promise<unknown | null>;
  sendPushWhenPuzzleExists?: boolean;
  syncLatestPuzzleFromExisting?: (
    existingPuzzle: Record<string, unknown>
  ) => Promise<void> | void;
  generatePuzzle: (targetDate: Date) => Promise<DailyPuzzleDocument>;
  persistPuzzle: (puzzle: DailyPuzzleDocument) => Promise<boolean | void>;
  sendPush: (puzzle: DailyPuzzlePushPayload, pushBody: string) => Promise<void>;
  formatPushBody: (emojiClue: string) => string;
  logger: LoggerLike;
}

export async function runDailyPuzzlePipeline(
  input: RunDailyPuzzlePipelineInput
): Promise<{ generated: boolean; pushSent: boolean }> {
  return runGenerateDailyPuzzleTask(input);
}
