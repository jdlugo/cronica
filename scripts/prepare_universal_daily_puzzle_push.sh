#!/usr/bin/env bash
set -euo pipefail

PROJECT_ID="${FIREBASE_PROJECT_ID:-admob-app-id-9658087638}"
WEB_API_KEY="${FIREBASE_WEB_API_KEY:-AIzaSyAdt_EM52cUKuMTsPyKyQJUYiawde2pOjY}"
APP_BUNDLE_ID="${APP_BUNDLE_ID:-com.dlugokecki.qscanlite}"
TARGET_DATE="${1:-$(date +%F)}"
COMPOSE_URL="https://console.firebase.google.com/project/${PROJECT_ID}/notification/compose"

for cmd in curl jq node; do
  if ! command -v "${cmd}" >/dev/null 2>&1; then
    printf "Missing required command: %s\n" "${cmd}" >&2
    exit 1
  fi
done

doc_url="https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents/dailyPuzzles/${TARGET_DATE}?key=${WEB_API_KEY}"
puzzle_json="$(curl -fsSL "${doc_url}")"

if printf "%s" "${puzzle_json}" | jq -e '.error' >/dev/null 2>&1; then
  printf "Could not load puzzle document for %s\n" "${TARGET_DATE}" >&2
  printf "%s\n" "${puzzle_json}" | jq -r '.error.message // .error'
  exit 1
fi

emoji_clue="$(printf "%s" "${puzzle_json}" | jq -r '.fields.emoji_clue.stringValue // empty')"
puzzle_id="$(printf "%s" "${puzzle_json}" | jq -r '.fields.puzzle_id.stringValue // empty')"
puzzle_date="$(printf "%s" "${puzzle_json}" | jq -r '.fields.date.stringValue // empty')"

if [[ -z "${emoji_clue}" || -z "${puzzle_id}" || -z "${puzzle_date}" ]]; then
  printf "Puzzle document is missing required fields (emoji_clue, puzzle_id, date)\n" >&2
  exit 1
fi

push_body="$(
  node - "${emoji_clue}" <<'NODE'
const clue = process.argv[2] || "";
const segmenter = new Intl.Segmenter("en", { granularity: "grapheme" });
const graphemes = Array.from(segmenter.segment(clue.replace(/\s+/gu, "")), (entry) => entry.segment)
  .filter((part) => part.trim().length > 0)
  .slice(0, 3);
while (graphemes.length < 3) {
  graphemes.push("?");
}
process.stdout.write(`${graphemes[0]} + ${graphemes[1]} + ${graphemes[2]} = ______`);
NODE
)"

campaign_name="Daily Puzzle ${puzzle_date} Universal Broadcast"

cat <<EOF
Universal Push Campaign Template
--------------------------------
Project: ${PROJECT_ID}
Compose URL: ${COMPOSE_URL}

Notification
- Title: Daily Puzzle 🎬
- Text: ${push_body}
- Name: ${campaign_name}

Target
- Type: User segment
- App: ${APP_BUNDLE_ID}
- Condition: (only app selected; no extra filters)

Scheduling
- Send now

Additional options
- Sound: Enabled
- Apple badge: 1

Custom data
- type=daily_puzzle
- puzzle_id=${puzzle_id}
- puzzle_date=${puzzle_date}

Validation checklist
1. Confirm app is ${APP_BUNDLE_ID} before send.
2. Confirm title/body exactly match above.
3. Confirm sound is Enabled and badge is 1.
4. Confirm custom data keys/values match above.
EOF

if [[ "${OPEN_CONSOLE:-0}" == "1" ]]; then
  if command -v open >/dev/null 2>&1; then
    open "${COMPOSE_URL}"
  else
    printf "\nOPEN_CONSOLE=1 was set, but 'open' command is unavailable.\n" >&2
  fi
fi
