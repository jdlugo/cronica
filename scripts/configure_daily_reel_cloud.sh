#!/usr/bin/env bash
set -euo pipefail

FIREBASE=(npx --yes firebase-tools@15.28.2)

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

PROJECT_ID="admob-app-id-9658087638"
PROJECT_NUMBER="315021799865"
EXPECTED_ACCOUNT="john@catapultlabs.net"
WEB_APP_ID="1:315021799865:web:87aad9db62c09193a54668"
SITE_ID="streaming-now-daily-reel"
SITE_URL="https://${SITE_ID}.web.app/"
KEY_DISPLAY_NAME="Streaming Now Daily Reel Web"

if [[ "${1:-}" != "--apply" ]]; then
  cat <<EOF
Dry run only. This command will:
  1. verify ${EXPECTED_ACCOUNT} is the active gcloud account
  2. enable Firebase Hosting, Firebase App Check, and reCAPTCHA Enterprise APIs
  3. create/bind ${SITE_ID} to ${WEB_APP_ID}
  4. create a score-based reCAPTCHA Enterprise key restricted to the Hosting domains
  5. register the key with Firebase App Check and write the public site key into web/index.html
  6. create missing Daily Reel Functions secrets without rotating existing values
  7. deploy only dailyReelAPI, publishDailyReel, ensureDailyReelPublished, and hosting:daily-reel

Re-run with --apply to perform these changes.
EOF
  exit 0
fi

active_account="$(gcloud auth list --filter=status:ACTIVE --format='value(account)')"
if [[ "$active_account" != "$EXPECTED_ACCOUNT" ]]; then
  echo "Expected active gcloud account ${EXPECTED_ACCOUNT}; found ${active_account:-none}." >&2
  exit 1
fi

gcloud services enable \
  firebasehosting.googleapis.com \
  firebaseappcheck.googleapis.com \
  recaptchaenterprise.googleapis.com \
  --project "$PROJECT_ID"

site_exists=false
for attempt in 1 2 3 4 5 6; do
  if sites_json="$("${FIREBASE[@]}" hosting:sites:list --project "$PROJECT_ID" --json 2>/dev/null)"; then
    if jq -e --arg id "$SITE_ID" 'any(.. | strings; . == $id or endswith("/sites/" + $id))' \
      <<<"$sites_json" >/dev/null; then
      site_exists=true
    fi
    break
  fi
  sleep 10
done

if [[ "$site_exists" != true ]]; then
  "${FIREBASE[@]}" hosting:sites:create "$SITE_ID" --app "$WEB_APP_ID" --project "$PROJECT_ID"
fi
"${FIREBASE[@]}" target:apply hosting daily-reel "$SITE_ID" --project "$PROJECT_ID"

key_names="$(gcloud recaptcha keys list \
  --project "$PROJECT_ID" \
  --format=json \
  | jq -r --arg displayName "$KEY_DISPLAY_NAME" \
      '.[] | select(.displayName == $displayName) | .name')"
key_count="$(printf '%s\n' "$key_names" | awk 'NF { count += 1 } END { print count + 0 }')"
if (( key_count > 1 )); then
  echo "More than one reCAPTCHA key named '${KEY_DISPLAY_NAME}' exists; refusing to guess." >&2
  exit 1
fi
if (( key_count == 0 )); then
  key_name="$(gcloud recaptcha keys create \
    --project "$PROJECT_ID" \
    --display-name "$KEY_DISPLAY_NAME" \
    --web \
    --domains "${SITE_ID}.web.app,${SITE_ID}.firebaseapp.com" \
    --integration-type score \
    --format='value(name)')"
else
  key_name="$(printf '%s\n' "$key_names" | awk 'NF { print; exit }')"
fi
site_key="${key_name##*/}"
if [[ -z "$site_key" ]]; then
  echo "Unable to resolve the reCAPTCHA Enterprise site key." >&2
  exit 1
fi

access_token="$(gcloud auth print-access-token --account "$EXPECTED_ACCOUNT")"
app_check_name="projects/${PROJECT_NUMBER}/apps/${WEB_APP_ID}/recaptchaEnterpriseConfig"
jq -n \
  --arg name "$app_check_name" \
  --arg siteKey "$site_key" \
  '{name:$name,siteKey:$siteKey,tokenTtl:"3600s"}' \
  | curl -fsS --retry 3 \
      -X PATCH \
      -H "Authorization: Bearer ${access_token}" \
      -H "X-Goog-User-Project: ${PROJECT_ID}" \
      -H "Content-Type: application/json" \
      --data-binary @- \
      "https://firebaseappcheck.googleapis.com/v1/${app_check_name}?updateMask=siteKey,tokenTtl" \
      >/dev/null

DAILY_REEL_SITE_KEY="$site_key" node <<'NODE'
const fs = require("node:fs");
const path = "web/index.html";
const input = fs.readFileSync(path, "utf8");
const output = input.replace(
  /recaptchaEnterpriseSiteKey: "[^"]*"/,
  `recaptchaEnterpriseSiteKey: "${process.env.DAILY_REEL_SITE_KEY}"`,
);
if (output === input && !input.includes(`recaptchaEnterpriseSiteKey: "${process.env.DAILY_REEL_SITE_KEY}"`)) {
  throw new Error("web/index.html has no replaceable App Check site-key field");
}
fs.writeFileSync(path, output);
NODE

ensure_secret() {
  local name="$1"
  local value="$2"
  if gcloud secrets describe "$name" --project "$PROJECT_ID" >/dev/null 2>&1; then
    echo "Preserving existing secret ${name}."
    return
  fi
  printf '%s' "$value" \
    | "${FIREBASE[@]}" functions:secrets:set "$name" --data-file=- --project "$PROJECT_ID"
}

posthog_project_token="$(sed -n 's/.*posthogProjectToken: "\([^"]*\)".*/\1/p' web/index.html | head -1)"
if [[ "$posthog_project_token" != phc_* ]]; then
  echo "Unable to resolve the PostHog project token from web/index.html." >&2
  exit 1
fi
ensure_secret DAILY_REEL_CAPABILITY_SECRET "$(openssl rand -hex 48)"
ensure_secret POSTHOG_PROJECT_TOKEN "$posthog_project_token"
ensure_secret DAILY_REEL_SHARE_BASE_URL "$SITE_URL"

"${FIREBASE[@]}" deploy \
  --project "$PROJECT_ID" \
  --only "functions:dailyReelAPI,functions:publishDailyReel,functions:ensureDailyReelPublished,hosting:daily-reel"

echo "Daily Reel cloud foundation deployed at ${SITE_URL}; rollout remains controlled by PostHog."
