import { getApps, initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { DailyReelAdminService } from "./dailyReelAdminHandlers.js";
import { loadDailyReelCandidateSource } from "./dailyReelCandidateSource.js";
import {
  DailyReelCoverageService,
  FirestoreDailyReelCoverageStore,
  type DailyReelEvergreenRecord,
} from "./dailyReelCoverage.js";
import { DailyReelGenerator } from "./dailyReelGenerator.js";
import { DailyReelPipeline } from "./dailyReelPipeline.js";
import {
  FirestoreDailyReelRepository,
  InMemoryDailyReelRepository,
  type DailyReelRepository,
} from "./dailyReelRepository.js";

const PROJECT_ID = "admob-app-id-9658087638";
const args = process.argv.slice(2);

function option(name: string): string | undefined {
  const index = args.indexOf(name);
  return index >= 0 ? args[index + 1] : undefined;
}

function requiredOption(name: string): string {
  const value = option(name)?.trim();
  if (!value) throw new Error(`${name} is required`);
  return value;
}

function requireApply(): void {
  if (!args.includes("--apply")) {
    throw new Error("This operation changes Firestore. Re-run with --apply after reviewing the local validation output.");
  }
}

function firestore() {
  if (getApps().length === 0) initializeApp({ projectId: PROJECT_ID });
  return getFirestore();
}

async function runCandidatePipeline(
  sourcePath: string,
  repository: DailyReelRepository,
) {
  const source = await loadDailyReelCandidateSource(sourcePath);
  const generator = new DailyReelGenerator({ generate: async () => source.payload });
  return new DailyReelPipeline(generator, repository).generateAndValidate(source.request);
}

function printCandidate(result: Awaited<ReturnType<typeof runCandidatePipeline>>): void {
  console.log(JSON.stringify({
    candidateId: result.candidate.candidateId,
    publicationId: result.candidate.intendedPublicationId,
    contentVersion: result.candidate.privateReel.reel.contentVersion,
    state: result.candidate.state,
    quality: result.qualityReport,
    replacementQueued: result.replacementQueued,
  }, null, 2));
}

async function main(): Promise<void> {
  const command = args[0];
  switch (command) {
  case "validate": {
    const result = await runCandidatePipeline(requiredOption("--file"), new InMemoryDailyReelRepository());
    printCandidate(result);
    if (!result.qualityReport.passed) process.exitCode = 1;
    return;
  }
  case "stage": {
    const sourcePath = requiredOption("--file");
    const preview = await runCandidatePipeline(sourcePath, new InMemoryDailyReelRepository());
    printCandidate(preview);
    if (!preview.qualityReport.passed) throw new Error("Candidate failed local quality validation");
    requireApply();
    printCandidate(await runCandidatePipeline(sourcePath, new FirestoreDailyReelRepository(firestore())));
    return;
  }
  case "approve": {
    requireApply();
    const publicationId = requiredOption("--publication");
    const schedule = await new DailyReelAdminService(new FirestoreDailyReelRepository(firestore())).approve({
      candidateId: requiredOption("--candidate"),
      publicationId,
      actor: { actorId: requiredOption("--actor"), canReviewDailyReels: true },
    });
    console.log(JSON.stringify(schedule, null, 2));
    return;
  }
  case "publish": {
    requireApply();
    const publication = await new DailyReelCoverageService(
      new FirestoreDailyReelCoverageStore(firestore()),
    ).publish(requiredOption("--publication"));
    console.log(JSON.stringify(publication, null, 2));
    return;
  }
  case "evergreen": {
    requireApply();
    const candidateId = requiredOption("--candidate");
    const repository = new FirestoreDailyReelRepository(firestore());
    const candidate = await repository.getCandidate(candidateId);
    if (!candidate?.approvedVersionId || !candidate.approvedAt || !candidate.approvedBy) {
      throw new Error("Evergreen content must reference a previously approved candidate version");
    }
    const priority = Number(option("--priority") ?? "10");
    const cooldownDays = Number(option("--cooldown-days") ?? "1");
    if (!Number.isInteger(priority)) throw new Error("--priority must be an integer");
    if (!Number.isInteger(cooldownDays) || cooldownDays < 1) {
      throw new Error("--cooldown-days must be a positive integer");
    }
    const evergreenId = option("--id")?.trim() || `evergreen-${candidate.approvedVersionId}`;
    const record: DailyReelEvergreenRecord = {
      evergreenId,
      versionId: candidate.approvedVersionId,
      candidateId,
      approvedAt: candidate.approvedAt,
      approvedBy: candidate.approvedBy,
      eligible: true,
      priority,
      cooldownDays,
      lastUsedPublicationId: null,
      lastUsedAt: null,
    };
    const reference = firestore().collection("dailyReelEvergreen").doc(evergreenId);
    const existing = await reference.get();
    if (existing.exists) {
      const current = existing.data() as DailyReelEvergreenRecord;
      if (current.versionId !== record.versionId || current.candidateId !== record.candidateId) {
        throw new Error(`Evergreen ID ${evergreenId} already references different content`);
      }
      console.log(JSON.stringify(current, null, 2));
      return;
    }
    await reference.create(record);
    console.log(JSON.stringify(record, null, 2));
    return;
  }
  case "status": {
    const candidate = await new FirestoreDailyReelRepository(firestore())
      .getCandidate(requiredOption("--candidate"));
    console.log(JSON.stringify(candidate && {
      candidateId: candidate.candidateId,
      publicationId: candidate.intendedPublicationId,
      contentVersion: candidate.privateReel.reel.contentVersion,
      state: candidate.state,
      qualityReport: candidate.qualityReport,
      approvedAt: candidate.approvedAt,
      approvedBy: candidate.approvedBy,
    }, null, 2));
    return;
  }
  case "queue-health": {
    const health = await new DailyReelCoverageService(
      new FirestoreDailyReelCoverageStore(firestore()),
    ).evaluateQueue({ firstPublicationId: requiredOption("--first") });
    console.log(JSON.stringify(health, null, 2));
    return;
  }
  default:
    throw new Error(
      "Usage: dailyReelOpsCLI.ts <validate|stage|approve|publish|evergreen|status|queue-health> [options]",
    );
  }
}

main().catch((error: unknown) => {
  console.error(error instanceof Error ? error.message : error);
  process.exit(1);
});
