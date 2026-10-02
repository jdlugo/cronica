#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ADMOB_ENV_FILE:-${ROOT_DIR}/.env.admob.local}"
OUTPUT_DIR="${ADMOB_OUTPUT_DIR:-${ROOT_DIR}/docs}"
HISTORY_CSV="${OUTPUT_DIR}/admob_history.csv"
WEEKLY_MD="${OUTPUT_DIR}/admob_weekly_report.md"

if [[ ! -f "${ENV_FILE}" ]]; then
  printf "Missing env file: %s\n" "${ENV_FILE}" >&2
  printf "Create it from .env.admob.local.example and fill OAuth credentials.\n" >&2
  exit 1
fi

# shellcheck disable=SC1090
source "${ENV_FILE}"

required_vars=(
  ADMOB_PUBLISHER_ID
  ADMOB_CLIENT_ID
  ADMOB_CLIENT_SECRET
  ADMOB_REFRESH_TOKEN
)

for var_name in "${required_vars[@]}"; do
  if [[ -z "${!var_name:-}" ]]; then
    printf "Missing required env var in %s: %s\n" "${ENV_FILE}" "${var_name}" >&2
    exit 1
  fi
done

days="${ADMOB_REPORT_DAYS:-14}"
currency="${ADMOB_REPORT_CURRENCY:-USD}"
language="${ADMOB_REPORT_LANGUAGE:-en-US}"
country_filter="${ADMOB_COUNTRY_FILTER:-}"

today_utc="$(date -u +%Y-%m-%d)"
start_date="$(date -u -v-"${days}"d +%Y-%m-%d)"

mkdir -p "${OUTPUT_DIR}"

cmd=(
  python3 "${ROOT_DIR}/scripts/pull_admob_report.py"
  --publisher-id "${ADMOB_PUBLISHER_ID}"
  --start-date "${start_date}"
  --end-date "${today_utc}"
  --output "${HISTORY_CSV}"
  --app "${ADMOB_APP_ID:-}"
  --currency "${currency}"
  --language "${language}"
  --client-id "${ADMOB_CLIENT_ID}"
  --client-secret "${ADMOB_CLIENT_SECRET}"
  --refresh-token "${ADMOB_REFRESH_TOKEN}"
)

if [[ -n "${country_filter}" ]]; then
  cmd+=(--country "${country_filter}")
fi

printf "Pulling AdMob report from %s to %s...\n" "${start_date}" "${today_utc}"
"${cmd[@]}"

python3 "${ROOT_DIR}/scripts/analyze_admob_weekly.py" \
  --input "${HISTORY_CSV}" \
  --output "${WEEKLY_MD}"

printf "\nDone.\n"
printf "CSV: %s\n" "${HISTORY_CSV}"
printf "Weekly report: %s\n" "${WEEKLY_MD}"
