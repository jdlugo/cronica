#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_DIR="${RELEASE_HEALTH_OUTPUT_DIR:-${ROOT_DIR}/docs}"
POSTHOG_OUTPUT="${OUTPUT_DIR}/posthog_release_health.txt"
INTERNATIONAL_OUTPUT="${OUTPUT_DIR}/international_growth_report.md"
INTERNATIONAL_DATA_DIR="${INTERNATIONAL_GROWTH_DATA_DIR:-${ROOT_DIR}/.build/international-growth/app-store-connect}"
INTERNATIONAL_DAILY_CSV="${INTERNATIONAL_GROWTH_CSV:-${ROOT_DIR}/.build/international-growth/territory_daily.csv}"
PRODUCT_PAGE_DAILY_CSV="${PRODUCT_PAGE_GROWTH_CSV:-${ROOT_DIR}/.build/international-growth/product_page_daily.csv}"
ADMOB_HISTORY="${ADMOB_HISTORY_CSV:-${ROOT_DIR}/docs/admob_history.csv}"

ENV_FILE="${RELEASE_HEALTH_ENV_FILE:-${ROOT_DIR}/.env}"
if [[ -f "$ENV_FILE" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  set +a
fi

ASC_KEY_ID="${ASC_KEY_ID:-439479CNWQ}"
ASC_ISSUER_ID="${ASC_ISSUER_ID:-69a6de7b-b570-47e3-e053-5b8c7c11a4d1}"
ASC_KEY_PATH="${ASC_KEY_PATH:-${HOME}/.appstoreconnect/private_keys/AuthKey_439479CNWQ.p8}"
export ASC_KEY_ID ASC_ISSUER_ID ASC_KEY_PATH

mkdir -p "$OUTPUT_DIR"

: "${POSTHOG_API_TOKEN:?Set POSTHOG_API_TOKEN to a PostHog personal API key.}"

printf 'Running version-aware PostHog release audit...\n'
POSTHOG_DAYS_BACK="${POSTHOG_DAYS_BACK:-14}" \
  "${ROOT_DIR}/scripts/posthog_audit.sh" | tee "$POSTHOG_OUTPUT"

printf '\nRefreshing AdMob revenue report...\n'
ADMOB_REPORT_DAYS="${ADMOB_REPORT_DAYS:-14}" \
  "${ROOT_DIR}/scripts/run_admob_latest.sh"

printf '\nRefreshing international territory funnel...\n'
if [[ -n "${ASC_KEY_ID:-}" && -n "${ASC_ISSUER_ID:-}" && -n "${ASC_KEY_PATH:-}" ]]; then
  (
    cd "$ROOT_DIR"
    python3 scripts/pull_app_store_analytics.py \
      --output-dir "$INTERNATIONAL_DATA_DIR"
  )
elif [[ -d "$INTERNATIONAL_DATA_DIR" ]]; then
  printf 'Using cached App Store analytics at %s.\n' "$INTERNATIONAL_DATA_DIR"
else
  printf 'International growth skipped: set ASC_KEY_ID, ASC_ISSUER_ID, and ASC_KEY_PATH or provide cached data at %s.\n' "$INTERNATIONAL_DATA_DIR"
fi

if [[ -d "$INTERNATIONAL_DATA_DIR" ]]; then
  (
    cd "$ROOT_DIR"
    python3 scripts/analyze_international_growth.py \
      --app-store-dir "$INTERNATIONAL_DATA_DIR" \
      --admob-csv "$ADMOB_HISTORY" \
      --output "$INTERNATIONAL_OUTPUT" \
      --csv-output "$INTERNATIONAL_DAILY_CSV" \
      --page-csv-output "$PRODUCT_PAGE_DAILY_CSV"
  )
fi

printf '\nRelease health reports ready.\n'
printf 'PostHog: %s\n' "$POSTHOG_OUTPUT"
printf 'AdMob: %s\n' "${OUTPUT_DIR}/admob_weekly_report.md"
if [[ -f "$INTERNATIONAL_OUTPUT" ]]; then
  printf 'International: %s\n' "$INTERNATIONAL_OUTPUT"
fi
