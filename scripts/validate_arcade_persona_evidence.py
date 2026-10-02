#!/usr/bin/env python3
"""Validate recorded Arcade persona evidence; no human fun claims are inferred."""
from __future__ import annotations

import argparse
import csv
import hashlib
import json
import re
import sys
from collections import Counter, defaultdict
from pathlib import Path
from html.parser import HTMLParser
from urllib.parse import unquote, urlparse

PERSONAS = {f"P{index}" for index in range(1, 8)}
GAMES = {"scene", "scramble", "casting", "timeline", "oddOneOut", "doubleFeature",
         "detective", "memory", "heist", "directorsCut"}
OUTCOMES = {"earned", "earned_with_help", "revealed_after_stop", "ui_blocked", "automation_failed"}
GAMEPLAY_TYPES = {"attempt", "help", "selection", "progress"}
EXCLUDED_TYPES = {"result_inspection", "live_visual_judgment", "scripted_replay",
                  "terminate_relaunch", "administrative_reveal", "learned_visible_cards"}
NAVIGATION = {"home", "explore", "watchlist"}


class PreviewParser(HTMLParser):
    def __init__(self):
        super().__init__()
        self.links = []
        self.in_data = False
        self.data = ""

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        self.links.extend(attrs[key] for key in ("href", "src") if attrs.get(key))
        if tag == "script" and attrs.get("id") == "data":
            self.in_data = True

    def handle_endtag(self, tag):
        if tag == "script":
            self.in_data = False

    def handle_data(self, data):
        if self.in_data:
            self.data += data


def preview_links(directory, payload, errors):
    links = []
    html_file = directory / "index.html"
    if html_file.is_file():
        parser = PreviewParser()
        parser.feed(html_file.read_text(encoding="utf-8"))
        links += parser.links
        try:
            embedded = json.loads(parser.data)
            if embedded.get("cells") != payload["cells"]:
                errors.append("HTML embedded observations differ from normalized cells.json")
        except json.JSONDecodeError:
            errors.append("HTML preview lacks valid embedded evidence JSON")
    md_file = directory / "comparison.md"
    if md_file.is_file():
        links += re.findall(r"\]\(([^)]+)\)", md_file.read_text(encoding="utf-8"))
    csv_file = directory / "observations.csv"
    if csv_file.is_file():
        with csv_file.open(encoding="utf-8", newline="") as handle:
            for row in csv.DictReader(handle):
                if row.get("trace_file"):
                    links.append(row["trace_file"])
                links += [reference for reference in row.get("screenshot_files", "").split(";") if reference]
    checked = 0
    for reference in links:
        if reference.startswith("#"):
            continue
        try:
            local_file(directory, reference)
            checked += 1
        except ValueError as error:
            errors.append(f"Comparison preview: {error}")
    return checked


def read_json(path):
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError):
        return None


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def local_file(root, reference):
    """Resolve artifact links; refuse schemes, absolute paths, traversal and symlinks out."""
    if not isinstance(reference, str) or not reference:
        raise ValueError("Missing or non-text evidence link")
    parsed = urlparse(reference)
    if parsed.scheme or parsed.netloc:
        raise ValueError(f"Nonlocal evidence link: {reference}")
    relative = Path(unquote(parsed.path))
    if relative.is_absolute():
        raise ValueError(f"Absolute evidence link: {reference}")
    path = (root / relative).resolve()
    if not path.is_relative_to(root):
        raise ValueError(f"Evidence link escapes artifact directory: {reference}")
    if not path.is_file():
        raise ValueError(f"Evidence link does not resolve to a file: {reference}")
    return path


def original_index(directory):
    entries = defaultdict(list)
    for path in sorted(directory.rglob("*")):
        if not path.is_file() or path.stat().st_size > 10_000_000:
            continue
        if path.suffix.lower() in {".png", ".jpg", ".jpeg", ".webp"}:
            continue
        trace = read_json(path)
        if isinstance(trace, dict) and all(key in trace for key in ("schema", "persona", "game", "actions")):
            entries[(trace["persona"], trace["game"])].append(path)
    return entries


def validate(directory, input_directory=None, allow_partial=False):
    errors, warnings = [], []
    payload = read_json(directory / "cells.json")
    if not isinstance(payload, dict) or not isinstance(payload.get("cells"), list):
        return {"success": False, "errors": ["Missing or invalid normalized cells.json"],
                "warnings": [], "evidence_type": "assigned simulator traces; not human fun evidence"}
    cells = payload["cells"]
    keys = [(cell.get("persona"), cell.get("game")) for cell in cells if isinstance(cell, dict)]
    counts = Counter(keys)
    expected = {(persona, game) for persona in PERSONAS for game in GAMES}
    missing = sorted(expected - set(keys))
    unknown = sorted(set(keys) - expected, key=str)
    duplicates = [f"{p}/{g}" for (p, g), count in counts.items() if count > 1]
    if len(keys) != len(cells):
        errors.append("Normalized cells must all be objects")
    if unknown:
        errors.append(f"Unknown persona/game combinations: {unknown}")
    if duplicates:
        errors.append(f"Duplicate combinations: {duplicates}")
    if missing and not allow_partial:
        errors.append(f"Only {len(set(keys) & expected)}/70 combinations; missing {len(missing)}")
    if missing and allow_partial:
        warnings.append(f"PARTIAL validation: {len(set(keys) & expected)}/70 cells, {len(missing)} missing. This is not final 70-cell evidence.")
    if payload.get("recorded_cells") != len(cells):
        errors.append("recorded_cells disagrees with normalized cell count")
    if payload.get("complete") != (not missing and not unknown and not duplicates):
        errors.append("Normalized complete flag disagrees with actual combination coverage")
    expected_missing = {(row.get("persona"), row.get("game")) for row in payload.get("missing", []) if isinstance(row, dict)}
    if expected_missing != set(missing):
        errors.append("Normalized missing list disagrees with actual missing combinations")
    originals = original_index(input_directory) if input_directory else None
    verified_hashes = trace_count = screenshot_count = tap_verified = contaminated_count = terminal_count = vision_count = 0
    for cell in cells:
        if not isinstance(cell, dict):
            continue
        key = (cell.get("persona"), cell.get("game"))
        cell_id = f"{key[0]}/{key[1]}"
        try:
            trace_path = local_file(directory, cell.get("trace_file"))
        except ValueError as error:
            errors.append(f"{cell_id}: {error}")
            continue
        raw = read_json(trace_path)
        if not isinstance(raw, dict) or raw.get("persona") != key[0] or raw.get("game") != key[1]:
            errors.append(f"{cell_id}: raw trace missing, invalid, or wrong identity")
            continue
        trace_count += 1
        if originals is not None:
            candidates = originals.get(key, [])
            matched = [path for path in candidates if sha256(path) == sha256(trace_path)]
            if not matched:
                errors.append(f"{cell_id}: copied raw trace differs from or is absent in original input")
            else:
                verified_hashes += 1
                if len(candidates) > 1:
                    warnings.append(f"{cell_id}: input contains {len(candidates)} originals; saved trace checksum matches {len(matched)}")
        for field in ("persona", "game", "outcome", "actions", "action_count", "help_count", "attempt_count", "points_label", "stop_reason"):
            if cell.get(field) != raw.get(field):
                errors.append(f"{cell_id}: normalized {field} altered the raw observation")
        actions = raw.get("actions")
        if not isinstance(actions, list) or any(not isinstance(action, dict) for action in actions):
            errors.append(f"{cell_id}: malformed ordered action list")
            continue
        types = Counter(action.get("type") for action in actions)
        unknown_types = set(types) - GAMEPLAY_TYPES - EXCLUDED_TYPES
        if unknown_types:
            warnings.append(f"{cell_id}: unknown action types {sorted(unknown_types, key=str)}; full gameplay tap invariant cannot be established")
        taps = sum(action.get("type") in GAMEPLAY_TYPES and not action.get("admin", False) for action in actions)
        if not unknown_types:
            if raw.get("action_count") != taps:
                errors.append(f"{cell_id}: action_count={raw.get('action_count')} differs from {taps} ordered nonadmin gameplay taps")
            else:
                tap_verified += 1
        for field, action_type in (("help_count", "help"), ("attempt_count", "attempt")):
            if raw.get(field) != types[action_type]:
                errors.append(f"{cell_id}: {field} disagrees with ordered {action_type} actions")
        outcome = raw.get("outcome")
        reveal_count = types["administrative_reveal"]
        if outcome not in OUTCOMES:
            errors.append(f"{cell_id}: unknown outcome {outcome!r}")
        if outcome in {"earned", "earned_with_help"} and reveal_count:
            errors.append(f"{cell_id}: earned outcome includes administrative reveal")
        if outcome == "earned_with_help" and not types["help"]:
            errors.append(f"{cell_id}: earned_with_help without help action")
        if outcome == "earned" and types["help"]:
            errors.append(f"{cell_id}: earned outcome omits recorded help category")
        if outcome == "revealed_after_stop" and (not reveal_count or not raw.get("stop_reason")):
            errors.append(f"{cell_id}: revealed_after_stop needs stop reason and administrative reveal")
        inspections = [a for a in actions if a.get("type") == "result_inspection"]
        buttons = [str(button).strip().casefold() for action in inspections for button in action.get("displayed_buttons", [])]
        contaminated = bool(set(buttons) & NAVIGATION)
        scoped = bool(inspections) and all(action.get("scope") == "arcade_sheet" for action in inspections)
        unverified = contaminated or not scoped
        if unverified:
            contaminated_count += 1
            if cell.get("utility_action_found") is not None or cell.get("payment_gate_found") is not None:
                errors.append(f"{cell_id}: unscoped/background-contaminated result flags must normalize to unknown/null")
            expected_scope = "app_wide_background_controls_present" if contaminated else "scope_not_recorded"
            if cell.get("result_scan_scope") != expected_scope or cell.get("result_scan_unverified") is not True:
                errors.append(f"{cell_id}: missing unverified result-scan provenance")
            flags = {name: raw.get(name) for name in ("utility_action_found", "payment_gate_found")}
            if cell.get("raw_result_scan_flags") != flags:
                errors.append(f"{cell_id}: original result-scan flags not preserved")
        if not inspections:
            warnings.append(f"{cell_id}: result inspection scope absent; utility/payment route claims cannot be established")
        terminal = [a for a in actions if a.get("type") == "terminate_relaunch" and a.get("terminal_before_interruption") is True]
        if terminal:
            terminal_count += 1
            initial = cell.get("initial_result_before_relaunch")
            if not isinstance(initial, dict) or initial.get("before_signature") != terminal[0].get("before"):
                errors.append(f"{cell_id}: terminal relaunch requires initial earned-result metadata with exact before signature")
        stages = set()
        for screenshot in cell.get("screenshots", []):
            if not isinstance(screenshot, dict):
                errors.append(f"{cell_id}: malformed screenshot link")
                continue
            try:
                local_file(directory, screenshot.get("file"))
                screenshot_count += 1
            except ValueError as error:
                errors.append(f"{cell_id}: {error}")
            name = str(screenshot.get("name", "")) + " " + str(screenshot.get("file", ""))
            for stage in ("start", "result", "stop"):
                prefix = re.escape(f"persona-cell-{key[0]}-{key[1]}-{stage}")
                if re.search(prefix + r"(?:[._ -]|$)", name):
                    stages.add(stage)
        if "start" not in stages or not stages.intersection({"result", "stop"}):
            errors.append(f"{cell_id}: needs a start screenshot plus result or stop screenshot")
        if outcome == "revealed_after_stop" and not {"stop", "result"}.issubset(stages):
            errors.append(f"{cell_id}: administrative-reveal outcome needs both stop and result screenshots")
        image_stems = {Path(str(s.get("name", ""))).stem for s in cell.get("screenshots", []) if isinstance(s, dict)}
        for action in actions:
            if action.get("type") != "live_visual_judgment":
                continue
            expected_stem = Path(str(action.get("screenshot_path", ""))).stem
            if not expected_stem or expected_stem not in image_stems:
                errors.append(f"{cell_id}: live visual judgment lacks its exact named capture preview")
            else:
                vision_count += 1
    if originals is None:
        warnings.append("Original --input omitted: saved traces parse, but byte-for-byte provenance against originals was not verified")
    if payload.get("result_scan_unverified") != contaminated_count:
        errors.append("Top-level unverified result-scan count disagrees with unscoped/background-contaminated raw inspections")
    for artifact in ("index.html", "comparison.md", "comparison.csv", "observations.csv"):
        if not (directory / artifact).is_file():
            errors.append(f"Missing comparison artifact: {artifact}")
    preview_link_count = preview_links(directory, payload, errors)
    return {
        "success": not errors, "complete": not missing and not unknown and not duplicates,
        "partial": bool(missing), "expected_cells": 70, "recorded_cells": len(cells),
        "unique_cells": len(set(keys) & expected), "missing_cells": len(missing),
        "raw_traces_checked": trace_count, "raw_trace_original_checksums_verified": verified_hashes,
        "screenshot_links_checked": screenshot_count, "preview_links_checked": preview_link_count, "gameplay_tap_counts_verified": tap_verified,
        "result_scans_unverified": contaminated_count, "terminal_relaunch_metadata_checked": terminal_count,
        "live_visual_judgment_captures_verified": vision_count,
        "outcomes": dict(Counter(c.get("outcome") for c in cells if isinstance(c, dict))),
        "evidence_type": "assigned simulator persona traces; not human fun, voluntary replay, retention or purchase evidence",
        "errors": errors, "warnings": warnings,
    }


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--evidence", type=Path, required=True, help="Generated grid directory containing cells.json")
    parser.add_argument("--input", type=Path, help="Optional original trace attachment directory for checksum comparisons")
    parser.add_argument("--allow-partial", action="store_true", help="Explicitly validate an incomplete interim artifact")
    args = parser.parse_args(argv)
    root = args.evidence.resolve()
    if not root.is_dir() or (args.input is not None and not args.input.is_dir()):
        parser.error("Evidence and optional input must be existing directories")
    try:
        report = validate(root, args.input.resolve() if args.input else None, args.allow_partial)
    except (OSError, TypeError, ValueError) as error:
        report = {"success": False, "errors": [str(error)], "warnings": []}
    print(json.dumps(report, indent=2, ensure_ascii=False))
    return 0 if report["success"] else 2


if __name__ == "__main__":
    sys.exit(main())
