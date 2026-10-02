#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FUNCTIONS_DIR="${ROOT_DIR}/functions"

IOS_PROJECT="${IOS_PROJECT:-${ROOT_DIR}/Story.xcodeproj}"
IOS_SCHEME="${IOS_SCHEME:-Story (iOS)}"
SKIP_IOS="${SKIP_IOS:-0}"
# Endpoint smoke checks are optional for local runs and can be enabled with SKIP_DAILY_PUZZLE_SMOKE=0.
SKIP_DAILY_PUZZLE_SMOKE="${SKIP_DAILY_PUZZLE_SMOKE:-1}"

DAILY_PUZZLE_FUNCTIONS_BASE_URL="${DAILY_PUZZLE_FUNCTIONS_BASE_URL:-https://us-central1-admob-app-id-9658087638.cloudfunctions.net}"
DAILY_PUZZLE_LATEST_URL="${DAILY_PUZZLE_LATEST_URL:-${DAILY_PUZZLE_FUNCTIONS_BASE_URL%/}/getLatestDailyPuzzle}"
DAILY_PUZZLE_TEST_PUSH_URL="${DAILY_PUZZLE_TEST_PUSH_URL:-${DAILY_PUZZLE_FUNCTIONS_BASE_URL%/}/sendDailyPuzzleTestPush}"
DAILY_PUZZLE_SMOKE_TIMEOUT_SECONDS="${DAILY_PUZZLE_SMOKE_TIMEOUT_SECONDS:-30}"

detect_ios_destination() {
  local destination_id
  destination_id="$(
    xcodebuild -showdestinations \
      -project "${IOS_PROJECT}" \
      -scheme "${IOS_SCHEME}" 2>/dev/null | \
      awk '/platform:iOS Simulator/ && $0 !~ /Any iOS Simulator Device/ { print }' | \
      sed -n 's/.*id:\([^,}]*\).*/\1/p' | \
      head -n 1
  )"

  if [[ -n "${destination_id}" ]]; then
    printf "id=%s" "${destination_id}"
    return 0
  fi

  return 1
}

if [[ "${SKIP_IOS}" != "1" ]]; then
  if [[ -n "${IOS_DESTINATION:-}" ]]; then
    IOS_DESTINATION="${IOS_DESTINATION}"
  elif ! IOS_DESTINATION="$(detect_ios_destination)"; then
    printf "Unable to auto-detect an iOS Simulator destination. Set IOS_DESTINATION manually.\n" >&2
    exit 1
  fi
fi

run_step() {
  local step_name="$1"
  shift

  printf "\n==> %s\n" "${step_name}"
  "$@"
}

json_has_jq() {
  command -v jq >/dev/null 2>&1
}

validate_latest_puzzle_schema() {
  local payload="$1"

  if json_has_jq; then
    printf "%s" "${payload}" | jq -e '
      has("date") and
      has("puzzle_id") and
      has("media_type") and
      has("tmdb_id") and
      has("title") and
      has("emoji_clue") and
      has("hint_1") and
      has("hint_2") and
      has("accepted_answers") and
      has("source") and
      has("generated_at") and
      (.accepted_answers | type == "array") and
      (.accepted_answers | length > 0) and
      (.tmdb_id | type == "number")
    ' >/dev/null
    return
  fi

  printf "%s" "${payload}" | node -e '
    const fs = require("node:fs");
    const raw = fs.readFileSync(0, "utf8");
    const data = JSON.parse(raw);
    const required = [
      "date",
      "puzzle_id",
      "media_type",
      "tmdb_id",
      "title",
      "emoji_clue",
      "hint_1",
      "hint_2",
      "accepted_answers",
      "source",
      "generated_at"
    ];

    for (const key of required) {
      if (!(key in data)) {
        throw new Error(`Missing field: ${key}`);
      }
    }

    if (!Array.isArray(data.accepted_answers) || data.accepted_answers.length === 0) {
      throw new Error("accepted_answers must be a non-empty array");
    }

    if (typeof data.tmdb_id !== "number") {
      throw new Error("tmdb_id must be a number");
    }
  '
}

validate_test_push_response() {
  local payload="$1"

  if json_has_jq; then
    printf "%s" "${payload}" | jq -e '.ok == true and has("puzzle_id")' >/dev/null
    return
  fi

  printf "%s" "${payload}" | node -e '
    const fs = require("node:fs");
    const raw = fs.readFileSync(0, "utf8");
    const data = JSON.parse(raw);
    if (data.ok !== true) {
      throw new Error("Expected ok=true");
    }
    if (typeof data.puzzle_id !== "string" || data.puzzle_id.length === 0) {
      throw new Error("Expected puzzle_id string");
    }
  '
}

run_latest_puzzle_smoke() {
  local latest_response
  latest_response="$(
    curl -fsSL \
      --max-time "${DAILY_PUZZLE_SMOKE_TIMEOUT_SECONDS}" \
      "${DAILY_PUZZLE_LATEST_URL}"
  )"

  validate_latest_puzzle_schema "${latest_response}"
}

run_test_push_smoke() {
  local test_push_response
  test_push_response="$(
    curl -fsSL \
      --max-time "${DAILY_PUZZLE_SMOKE_TIMEOUT_SECONDS}" \
      -X POST \
      -H "x-admin-key: ${DAILY_PUZZLE_ADMIN_KEY}" \
      "${DAILY_PUZZLE_TEST_PUSH_URL}"
  )"

  validate_test_push_response "${test_push_response}"
}

run_step "Functions unit tests" \
  bash -lc "cd '${FUNCTIONS_DIR}' && npm test"

run_step "Functions TypeScript build" \
  bash -lc "cd '${FUNCTIONS_DIR}' && npm run build"

run_step "Functions Firestore emulator integration tests" \
  bash -lc "cd '${FUNCTIONS_DIR}' && npm run test:firestore"

if [[ "${SKIP_IOS}" == "1" ]]; then
  printf "\n==> Skipping iOS Daily Puzzle targeted suite (SKIP_IOS=1)\n"
else
  run_step "iOS Daily Puzzle targeted suite" \
    xcodebuild test \
      -project "${IOS_PROJECT}" \
      -scheme "${IOS_SCHEME}" \
      -destination "${IOS_DESTINATION}" \
      -only-testing:CronicaTests/DailyPuzzleViewModelTests \
      -only-testing:CronicaTests/DailyPuzzleServiceTests \
      -only-testing:CronicaTests/DailyPuzzlePushTopicManagerTests \
      -only-testing:CronicaTests/DailyPuzzleLaunchIntentStoreTests \
      -only-testing:CronicaTests/DailyPuzzleAdminConfigServiceTests
fi

if [[ "${SKIP_DAILY_PUZZLE_SMOKE}" == "1" ]]; then
  printf "\n==> Skipping Daily Puzzle endpoint smoke checks (default). Set SKIP_DAILY_PUZZLE_SMOKE=0 to enable.\n"
else
  run_step "Daily Puzzle latest endpoint schema smoke" run_latest_puzzle_smoke

  if [[ -n "${DAILY_PUZZLE_ADMIN_KEY:-}" ]]; then
    run_step "Daily Puzzle test push smoke" run_test_push_smoke
  else
    printf "\n==> Skipping Daily Puzzle test push smoke (DAILY_PUZZLE_ADMIN_KEY is not set)\n"
  fi
fi

printf "\n✅ Daily Puzzle release gate passed.\n"
