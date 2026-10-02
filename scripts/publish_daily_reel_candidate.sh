#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

EXPECTED_ACCOUNT="john@catapultlabs.net"
CANDIDATE_FILE="${2:-../contracts/daily-reel/v1/candidates/2026-09-02.json}"

if [[ "${1:-}" != "--apply" ]]; then
  cat <<EOF
Dry run only. This command will validate, stage, approve, and pre-publish:
  ${CANDIDATE_FILE}

Daily play remains blocked until the candidate's 05:00 UTC availability window,
and PostHog exposure remains 0%. Re-run with --apply to perform the Firestore writes.
EOF
  exit 0
fi

active_account="$(gcloud auth list --filter=status:ACTIVE --format='value(account)')"
if [[ "$active_account" != "$EXPECTED_ACCOUNT" ]]; then
  echo "Expected active gcloud account ${EXPECTED_ACCOUNT}; found ${active_account:-none}." >&2
  exit 1
fi
if ! gcloud auth application-default print-access-token >/dev/null 2>&1; then
  echo "Application Default Credentials are missing. Run gcloud auth application-default login first." >&2
  exit 1
fi

cd functions
validation="$(npm run daily-reel:ops --silent -- validate --file "$CANDIDATE_FILE")"
candidate_id="$(jq -r '.candidateId' <<<"$validation")"
publication_id="$(jq -r '.publicationId' <<<"$validation")"
quality_passed="$(jq -r '.quality.passed' <<<"$validation")"
if [[ -z "$candidate_id" || -z "$publication_id" || "$quality_passed" != true ]]; then
  echo "Candidate did not pass local validation." >&2
  jq '{candidateId,publicationId,quality}' <<<"$validation" >&2
  exit 1
fi

npm run daily-reel:ops --silent -- stage \
  --file "$CANDIDATE_FILE" \
  --apply
npm run daily-reel:ops --silent -- approve \
  --candidate "$candidate_id" \
  --publication "$publication_id" \
  --actor "$EXPECTED_ACCOUNT" \
  --apply
npm run daily-reel:ops --silent -- publish \
  --publication "$publication_id" \
  --apply

echo "Published candidate ${candidate_id} for ${publication_id}; daily access remains time-gated."
