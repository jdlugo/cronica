#!/usr/bin/env bash
set -euo pipefail

: "${POSTHOG_API_TOKEN:?Set POSTHOG_API_TOKEN (project personal key, e.g. phx_...).}"

POSTHOG_BASE_URL="${POSTHOG_BASE_URL:-https://us.posthog.com}"
POSTHOG_PROJECT_REF="${POSTHOG_PROJECT_REF:=@current}"
INSIGHTS_FILE="${POSTHOG_INSIGHTS_FILE:-docs/analytics/posthog_saved_insights.json}"
DRY_RUN="${DRY_RUN:-0}"

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required" >&2
  exit 1
fi

if [[ ! -f "$INSIGHTS_FILE" ]]; then
  echo "Missing insights file: $INSIGHTS_FILE" >&2
  exit 1
fi

api_post() {
  local payload="$1"
  curl -sS --fail-with-body --retry 4 --retry-all-errors --retry-delay 1 -X POST \
    -H "Authorization: Bearer ${POSTHOG_API_TOKEN}" \
    -H "Content-Type: application/json" \
    "${POSTHOG_BASE_URL}/api/projects/${POSTHOG_PROJECT_REF}/insights/" \
    --data "$payload"
}

api_patch() {
  local insight_id="$1"
  local payload="$2"
  curl -sS --fail-with-body --retry 4 --retry-all-errors --retry-delay 1 -X PATCH \
    -H "Authorization: Bearer ${POSTHOG_API_TOKEN}" \
    -H "Content-Type: application/json" \
    "${POSTHOG_BASE_URL}/api/projects/${POSTHOG_PROJECT_REF}/insights/${insight_id}/" \
    --data "$payload"
}

api_get() {
  curl -sS --fail-with-body --retry 4 --retry-all-errors --retry-delay 1 \
    -H "Authorization: Bearer ${POSTHOG_API_TOKEN}" \
    -H "Content-Type: application/json" \
    "${POSTHOG_BASE_URL}/api/projects/${POSTHOG_PROJECT_REF}/insights/?limit=200"
}

count=$(jq '.insights | length' "$INSIGHTS_FILE")
if [[ "$count" == "0" ]]; then
  echo "No insights found in $INSIGHTS_FILE"
  exit 0
fi

echo "Syncing ${count} insights from $INSIGHTS_FILE ..."

existing_by_name='{}'
if [[ "$DRY_RUN" != "1" ]]; then
  existing_by_name=$(api_get | jq -c 'reduce .results[]? as $insight ({}; .[$insight.name] = ($insight.id | tostring))')
fi

jq -c '.insights[]' "$INSIGHTS_FILE" | while read -r insight; do
  name=$(jq -r '.name' <<<"$insight")
  payload=$(jq -c '{name, description, query}' <<<"$insight")

  if [[ "$DRY_RUN" == "1" ]]; then
    echo "[dry-run] would sync: ${name}"
    continue
  fi

  existing_id=$(jq -r --arg name "$name" '.[$name] // empty' <<<"$existing_by_name")
  if [[ -n "$existing_id" ]]; then
    response=$(api_patch "$existing_id" "$payload")
    action="updated"
  else
    response=$(api_post "$payload")
    action="created"
  fi

  status=$(jq -r '.id // .detail // .code // .message // "error"' <<<"$response")
  if [[ "$status" == "error" ]] || [[ "$status" == "null" ]]; then
    echo "[error] ${name}"
    echo "$response"
  else
    short_id=$(jq -r '.short_id // "n/a"' <<<"$response")
    echo "[ok] ${action}: ${name} (short_id=${short_id})"
  fi
done

echo "Done."
