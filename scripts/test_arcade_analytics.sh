#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
analytics_scratch=$(mktemp -d)
trap 'rm -rf "$analytics_scratch"' EXIT
swiftc -module-cache-path "$analytics_scratch/module-cache" Shared/Model/MovieArcade.swift Shared/Model/ArcadeCatalog.swift Shared/Model/ArcadeAnalytics.swift scripts/tests/arcade_analytics_tests.swift -o "$analytics_scratch/analytics-tests"
"$analytics_scratch/analytics-tests"
