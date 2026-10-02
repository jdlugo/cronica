#!/usr/bin/env python3
"""Check bundled Arcade copy coverage, syntax and format argument compatibility."""
import json
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]
sources = [ROOT / "Shared/Model/MovieArcade.swift", ROOT / "Shared/View/Navigation/MovieArcadeView.swift"]
required = set()
for path in sources:
    text = path.read_text()
    for match in re.finditer(r'(?:arcadeText|Text|Label|Button|navigationTitle|accessibilityHint)\("((?:[^"\\]|\\.)*)"', text):
        key = match.group(1)
        if "\\(" not in key:
            required.add(json.loads('"' + key + '"'))
required.update(re.findall(r'plot: "([^"]+)"', (ROOT / "Shared/Model/ArcadeCatalog.swift").read_text()))
# Dynamic model copy must be explicitly translated as well.
required.update(["Recognize the scene? Tap the movie.", "Flip two cards to find a matching pair. Find all three to finish; the year question is optional."])
placeholder = re.compile(r'%(?:\d+\$)?[@dluif]')
tables = {}
english_path = ROOT / "Shared/Localization/en.lproj/Localizable.strings"
arcade_section = english_path.read_text().split("// MARK: Movie Arcade\n", 1)[1]
required.update(json.loads('"' + key + '"') for key in re.findall(r'^"((?:[^"\\]|\\.)*)"\s*=', arcade_section, re.M))
for locale in ["en", "es", "es-MX"]:
    path = ROOT / f"Shared/Localization/{locale}.lproj/Localizable.strings"
    result = subprocess.run(["plutil", "-convert", "json", "-o", "-", str(path)], capture_output=True, text=True, check=True)
    tables[locale] = json.loads(result.stdout)
    # Duplicate keys compile but silently override another screen's translation.
    keys = re.findall(r'^"((?:[^"\\]|\\.)*)"\s*=', path.read_text(), re.M)
    arcade_keys = set(re.findall(r'^"((?:[^"\\]|\\.)*)"\s*=', arcade_section, re.M))
    assert all(keys.count(key) == 1 for key in arcade_keys), f"{locale}: duplicate Arcade key"
    missing = required - tables[locale].keys()
    assert not missing, f"{locale} missing {len(missing)} Arcade keys: {sorted(missing)}"
    for key in required:
        assert tables[locale][key], f"{locale}: empty {key}"
        assert placeholder.findall(key) == placeholder.findall(tables[locale][key]), f"{locale}: format mismatch for {key}"
print(f"Arcade localization: {len(required)} keys covered in English, Spanish and Mexican Spanish; format arguments match")
