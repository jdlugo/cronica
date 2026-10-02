#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
scratch_dir=$(mktemp -d)
trap 'rm -rf "$scratch_dir"' EXIT
swift_compiler=${SWIFT_COMPILER:-$(xcrun --find swiftc)}
macos_sdk=${MACOS_SDK:-$(xcrun --sdk macosx --show-sdk-path)}
"$swift_compiler" -sdk "$macos_sdk" \
  Shared/Manager/DailyPuzzleReminderPolicy.swift scripts/tests/daily_puzzle_reminder_tests.swift \
  -o "$scratch_dir/reminder-tests"
"$scratch_dir/reminder-tests"
