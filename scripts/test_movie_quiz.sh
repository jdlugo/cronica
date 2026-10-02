#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
quiz_scratch=$(mktemp -d)
trap 'rm -rf "$quiz_scratch"' EXIT
swiftc Shared/Model/DailyPuzzle.swift scripts/tests/movie_quiz_tests.swift -o "$quiz_scratch/movie-quiz-tests"
"$quiz_scratch/movie-quiz-tests"
