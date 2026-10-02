#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PUZZLES_FILE="${ROOT_DIR}/scripts/practice_puzzles.json"
PROJECT_ID="${FIREBASE_PROJECT_ID:-admob-app-id-9658087638}"
TOKEN="$(gcloud auth application-default print-access-token)"
BASE_URL="https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents/dailyPuzzles"

jq -c '.[]' "${PUZZLES_FILE}" | while IFS= read -r puzzle; do
  id="$(jq -r '.id' <<<"${puzzle}")"
  body="$(jq -n --argjson puzzle "${puzzle}" '
  def localized_value:
    {mapValue: {fields: {
      title: {stringValue: .title},
      emoji_clue: {stringValue: .emoji_clue},
      hint_1: {stringValue: .hint_1},
      hint_2: {stringValue: .hint_2},
      accepted_answers: {arrayValue: {values: [.accepted_answers[] | {stringValue: .}]}}
    }}};
  {fields: ({
    date: {stringValue: $puzzle.date},
    puzzle_id: {stringValue: $puzzle.id},
    media_type: {stringValue: "movie"},
    tmdb_id: {integerValue: ($puzzle.tmdb_id | tostring)},
    title: {stringValue: $puzzle.title},
    emoji_clue: {stringValue: $puzzle.emoji_clue},
    hint_1: {stringValue: $puzzle.hint_1},
    hint_2: {stringValue: $puzzle.hint_2},
    accepted_answers: {arrayValue: {values: [$puzzle.accepted_answers[] | {stringValue: .}]}},
    source: {stringValue: "curated-easy"},
    practice_eligible: {booleanValue: true},
    generated_at: {stringValue: "2026-08-27T17:00:00.000Z"},
    updated_at: {stringValue: "2026-08-27T17:00:00.000Z"}
  } + (if $puzzle.localizations then {
    localizations: {mapValue: {fields: ($puzzle.localizations | with_entries(.value |= localized_value))}}
  } else {} end))}')"

  curl -fsS -X PATCH "${BASE_URL}/${id}" \
    -H "Authorization: Bearer ${TOKEN}" \
    -H 'Content-Type: application/json' \
    --data-binary "${body}" >/dev/null
  printf 'Seeded %s\n' "${id}"
done
