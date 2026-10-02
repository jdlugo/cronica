#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FUNCTIONS_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${FUNCTIONS_DIR}"

EMULATOR_HOST="127.0.0.1:8080"
PROJECT_ID="demo-daily-puzzle"
EMULATOR_LOG_FILE="${TMPDIR:-/tmp}/firestore-emulator-${RANDOM}.log"

cleanup() {
  if [[ -n "${EMULATOR_PID:-}" ]] && kill -0 "${EMULATOR_PID}" 2>/dev/null; then
    kill "${EMULATOR_PID}" 2>/dev/null || true
    wait "${EMULATOR_PID}" 2>/dev/null || true
  fi
}
trap cleanup EXIT

firebase emulators:start \
  --config firebase.json \
  --project "${PROJECT_ID}" \
  --only firestore >"${EMULATOR_LOG_FILE}" 2>&1 &
EMULATOR_PID=$!

for _ in {1..60}; do
  if nc -z 127.0.0.1 8080 2>/dev/null; then
    break
  fi
  sleep 1
done

if ! nc -z 127.0.0.1 8080 2>/dev/null; then
  echo "Firestore emulator failed to start. Log output:"
  cat "${EMULATOR_LOG_FILE}"
  exit 1
fi

export FIRESTORE_EMULATOR_HOST="${EMULATOR_HOST}"
export GCLOUD_PROJECT="${PROJECT_ID}"

node ./node_modules/vitest/vitest.mjs run src/__tests__/firestoreRepository.integration.test.ts
