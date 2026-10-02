#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
arcade_scratch=$(mktemp -d)
trap 'rm -rf "$arcade_scratch"' EXIT
swiftc -module-cache-path "$arcade_scratch/module-cache" Shared/Model/MovieArcade.swift Shared/Model/ArcadeCatalog.swift scripts/tests/movie_arcade_tests.swift -o "$arcade_scratch/arcade-tests"
"$arcade_scratch/arcade-tests"
