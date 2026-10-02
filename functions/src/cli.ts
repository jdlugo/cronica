import { formatPushBodyFromEmojiClue, generateDailyPuzzleDocument } from "./generator.js";
import { OpenAiStructuredPuzzleGenerator } from "./openaiClient.js";
import { fetchTmdbCandidate } from "./tmdb.js";

function parseDateArg(args: string[]): Date {
  const index = args.findIndex((arg) => arg === "--date");
  if (index < 0 || index + 1 >= args.length) {
    return new Date();
  }

  const parsed = new Date(`${args[index + 1]}T05:00:00.000Z`);
  if (Number.isNaN(parsed.getTime())) {
    throw new Error(`Invalid --date value: ${args[index + 1]}`);
  }

  return parsed;
}

async function main(): Promise<void> {
  const args = process.argv.slice(2);
  const targetDate = parseDateArg(args);

  const tmdbApiKey = process.env.TMDB_API_KEY;
  const openAiApiKey = process.env.OPENAI_API_KEY;

  if (!tmdbApiKey || !openAiApiKey) {
    throw new Error("Set TMDB_API_KEY and OPENAI_API_KEY before running dry generation");
  }

  const aiGenerator = new OpenAiStructuredPuzzleGenerator(openAiApiKey);
  const puzzle = await generateDailyPuzzleDocument({
    targetDate,
    tmdbFetcher: () => fetchTmdbCandidate({ apiKey: tmdbApiKey, targetDate }),
    aiGenerator
  });

  console.log(JSON.stringify(puzzle, null, 2));
  console.log(`push_body=${formatPushBodyFromEmojiClue(puzzle.emoji_clue)}`);
}

main().catch((error: unknown) => {
  console.error(error);
  process.exit(1);
});
