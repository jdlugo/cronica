#!/usr/bin/env bash
set -euo pipefail

: "${POSTHOG_API_TOKEN:?Set POSTHOG_API_TOKEN for project access (phx_...).}"

PROJECT_PATH="${PROJECT_PATH:-Story.xcodeproj}"
SCHEME="${SCHEME:-Story (iOS)}"
CONFIGURATION="${CONFIGURATION:-Release}"
DERIVED_DATA_DIR="${DERIVED_DATA_DIR:-build/DerivedData}"
DESTINATION="${DESTINATION:-generic/platform=iOS}"
DEVICE_QUERY="${DEVICE_QUERY:-Johns iPhone}"
APP_BUNDLE_ID="${APP_BUNDLE_ID:-com.dlugokecki.qscanlite}"
POSTHOG_PROJECT_REF="${POSTHOG_PROJECT_REF:-@current}"
POSTHOG_BASE_URL="${POSTHOG_BASE_URL:-https://us.posthog.com}"
CONSOLE_TIMEOUT="${CONSOLE_TIMEOUT:-20}"

log() {
  printf '[%s] %s\n' "$(date '+%H:%M:%S')" "$1"
}

resolve_device_id() {
  local query="$1"
  local device_json
  device_json="$(mktemp -t posthog-device-list-XXXXXX.json)"
  xcrun devicectl list devices --json-output "$device_json" >/dev/null

  local device_id
  device_id="$(jq -r --arg query "$query" '
    .result.devices[]
    | select(.connectionProperties.tunnelState == "connected")
    | select(
      (.deviceProperties.name == $query)
      or (.identifier == $query)
      or (.hardwareProperties.udid == $query)
      or (.connectionProperties.localHostnames // [] | any(. == $query))
      or ((.deviceProperties.name // "") | ascii_downcase) == ($query | ascii_downcase)
      or ((.identifier // "") | ascii_downcase) == ($query | ascii_downcase)
    )
    | .identifier
  ' "$device_json" | head -n 1)"

  if [[ -z "$device_id" ]]; then
    device_id="$(jq -r '.result.devices[] | select(.connectionProperties.tunnelState == "connected") | .identifier' "$device_json" | head -n 1)"
  fi

  rm -f "$device_json"
  echo "$device_id"
}

log "Checking for connected device..."
DEVICE_ID="$(resolve_device_id "$DEVICE_QUERY")"

if [[ -z "$DEVICE_ID" ]]; then
  log "Could not resolve connected device from DEVICE_QUERY=$DEVICE_QUERY"
  log "Run: xcrun devicectl list devices --json-output /tmp/devices.json"
  exit 1
fi

log "Resolved device id: $DEVICE_ID"

log "Building $SCHEME ($CONFIGURATION) for device..."
xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -destination "$DESTINATION" \
  -derivedDataPath "$DERIVED_DATA_DIR" \
  -allowProvisioningUpdates \
  build \
  CODE_SIGNING_ALLOWED=YES

APP_PATH="$DERIVED_DATA_DIR/Build/Products/${CONFIGURATION}-iphoneos/StreamingNow.app"
if [[ ! -d "$APP_PATH" ]]; then
  log "Expected app not found at $APP_PATH"
  exit 1
fi

log "Installing app on device..."
xcrun devicectl device install app --device "$DEVICE_ID" "$APP_PATH"

log "Launching app with console capture (this will fail if the device is locked)..."
CONSOLE_OUTPUT="$(mktemp -t posthog-console-XXXXXX.log)"
set +e
timeout "$CONSOLE_TIMEOUT" xcrun devicectl device process launch --device "$DEVICE_ID" --console --terminate-existing "$APP_BUNDLE_ID" > "$CONSOLE_OUTPUT" 2>&1
LAUNCH_EXIT=$?
set -e

if [[ $LAUNCH_EXIT -ne 0 ]]; then
  if rg -q "Unable to launch .* because the device was not, or could not be, unlocked" "$CONSOLE_OUTPUT"; then
    log "Launch blocked: device is locked. Unlock phone and run this script again."
  elif [[ $LAUNCH_EXIT -eq 124 ]]; then
    log "Console capture timed out after ${CONSOLE_TIMEOUT}s; proceeding to PostHog check with collected startup logs."
  else
    log "Launch exited with code $LAUNCH_EXIT"
    log "--- Device output ---"
    cat "$CONSOLE_OUTPUT"
    rm -f "$CONSOLE_OUTPUT"
    exit $LAUNCH_EXIT
  fi
fi

log "Startup console output:"
cat "$CONSOLE_OUTPUT"
rm -f "$CONSOLE_OUTPUT"

log "Checking PostHog project for recent relevant events..."
QUERY=$'SELECT event, count() AS total\nFROM events\nWHERE timestamp >= now() - INTERVAL 20 MINUTE\n  AND event IN (\'daily_puzzle_opened\', \'daily_puzzle_open_requested\', \'ad_interstitial_present\')\nGROUP BY event\nORDER BY total DESC;'

PAYLOAD="$(jq -cn --arg q "$QUERY" '{query:{kind:"HogQLQuery",query:$q}}')"
POSTHOG_HITS="$(curl -sS -H "Authorization: Bearer ${POSTHOG_API_TOKEN}" \
  -H 'Content-Type: application/json' \
  "${POSTHOG_BASE_URL}/api/projects/${POSTHOG_PROJECT_REF}/query/" \
  --data "$PAYLOAD")"

echo "$POSTHOG_HITS" | jq '{count: (.count // 0), results: (.results // [])}'
log "Done."
