#!/usr/bin/env bash
set -euo pipefail

PROJECT_ID="${FIREBASE_PROJECT_ID:-admob-app-id-9658087638}"
WEB_API_KEY="${FIREBASE_WEB_API_KEY:-AIzaSyAdt_EM52cUKuMTsPyKyQJUYiawde2pOjY}"
FUNCTIONS_BASE_URL="${DAILY_PUZZLE_FUNCTIONS_BASE_URL:-https://us-central1-${PROJECT_ID}.cloudfunctions.net}"

LATEST_FUNCTION_URL="${DAILY_PUZZLE_LATEST_URL:-${FUNCTIONS_BASE_URL%/}/getLatestDailyPuzzle}"
RANDOM_FUNCTION_URL="${DAILY_PUZZLE_RANDOM_URL:-${FUNCTIONS_BASE_URL%/}/getRandomDailyPuzzle}"
FIRESTORE_LATEST_URL="https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents/dailyPuzzles/latest?key=${WEB_API_KEY}"
FIRESTORE_COLLECTION_URL="https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents/dailyPuzzles?key=${WEB_API_KEY}&pageSize=100"

http_status() {
  local url="$1"
  curl -sS -o /tmp/daily-puzzle-verify-response.json -w "%{http_code}" "${url}"
}

print_header() {
  printf "\n==> %s\n" "$1"
}

print_header "Optional: Firebase Functions deployment status"
if command -v firebase >/dev/null 2>&1; then
  if firebase functions:list --project "${PROJECT_ID}" >/tmp/daily-puzzle-functions-list.txt 2>/tmp/daily-puzzle-functions-list.err; then
    if rg -q "getLatestDailyPuzzle|getRandomDailyPuzzle" /tmp/daily-puzzle-functions-list.txt; then
      printf "Functions look deployed.\n"
    else
      printf "WARNING: Daily puzzle functions are not deployed in project %s.\n" "${PROJECT_ID}"
      printf "         Function URLs will 404 until you deploy (requires Blaze plan).\n"
    fi
  else
    printf "WARNING: Could not query firebase functions:list for project %s.\n" "${PROJECT_ID}"
    cat /tmp/daily-puzzle-functions-list.err
  fi
else
  printf "firebase CLI not found; skipping deployment check.\n"
fi

print_header "Cloud Functions endpoint status"
latest_status="$(http_status "${LATEST_FUNCTION_URL}")"
printf "getLatestDailyPuzzle: %s\n" "${latest_status}"
random_status="$(http_status "${RANDOM_FUNCTION_URL}")"
printf "getRandomDailyPuzzle: %s\n" "${random_status}"

print_header "Firestore latest document"
firestore_latest_status="$(http_status "${FIRESTORE_LATEST_URL}")"
printf "Firestore latest status: %s\n" "${firestore_latest_status}"
if [[ "${firestore_latest_status}" != "200" ]]; then
  printf "ERROR: Firestore latest document request failed.\n"
  cat /tmp/daily-puzzle-verify-response.json
  exit 1
fi

curl -sS "${FIRESTORE_LATEST_URL}" | jq -r '
  "puzzle_id: \(.fields.puzzle_id.stringValue // "missing")",
  "title: \(.fields.title.stringValue // "missing")",
  "emoji: \(.fields.emoji_clue.stringValue // "missing")"
'

print_header "Firestore collection sample"
collection_json="$(curl -sS "${FIRESTORE_COLLECTION_URL}")"
doc_count="$(printf "%s" "${collection_json}" | jq '.documents | length')"
printf "documents returned: %s\n" "${doc_count}"

if [[ "${doc_count}" == "0" ]]; then
  printf "ERROR: No daily puzzle documents found.\n"
  exit 1
fi

printf "%s" "${collection_json}" | jq -r '
  .documents
  | map(select(.name | endswith("/latest") | not))
  | map(.fields.puzzle_id.stringValue)
  | map(select(. != null))
  | .[0:5]
  | "sample puzzle_ids: \(join(", "))"
'

print_header "Summary"
if [[ "${latest_status}" != "200" || "${random_status}" != "200" ]]; then
  printf "Functions are not healthy (or not deployed), but Firestore data is available.\n"
  printf "The app can still use Firestore-first puzzle loading.\n"
else
  printf "Functions + Firestore look healthy.\n"
fi
