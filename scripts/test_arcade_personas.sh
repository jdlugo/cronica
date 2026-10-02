#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
persona_scratch=$(mktemp -d)
trap 'rm -rf "$persona_scratch"' EXIT
swiftc -module-cache-path "$persona_scratch/module-cache" Shared/Model/MovieArcade.swift Shared/Model/ArcadeCatalog.swift Shared/Model/ArcadeAnalytics.swift scripts/tests/arcade_persona_probes.swift -o "$persona_scratch/persona-probes"
"$persona_scratch/persona-probes"
