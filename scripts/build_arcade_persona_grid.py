#!/usr/bin/env python3
"""Build an evidence-linked persona/game grid from exported XCTest attachments.

This formats recorded simulator traces, not human enjoyment or retention ratings.
No third-party packages are required. Missing cells are fatal unless --allow-partial.
"""
from __future__ import annotations

import argparse
import csv
import json
import re
import shutil
import sys
from collections import Counter
from pathlib import Path

PERSONAS = {
    "P1": "Sam · visual newcomer", "P2": "Alex · movie fan",
    "P3": "Jordan · interrupted player", "P4": "Casey · discovery first",
    "P5": "Morgan · larger text", "P6": "Riley · skeptical buyer",
    "P7": "Taylor · multilingual viewer",
}
GAMES = {
    "scene": "Scene Spotter", "scramble": "Movie Scramble",
    "casting": "Casting Call", "timeline": "Before or After?",
    "oddOneOut": "Odd Movie Out", "doubleFeature": "Double Feature",
    "detective": "Movie Detective", "memory": "Poster Memory",
    "heist": "Movie Heist", "directorsCut": "Director’s Cut",
}
OUTCOMES = {
    "earned": "Earned", "earned_with_help": "Earned + help",
    "revealed_after_stop": "Stopped → reveal", "ui_blocked": "UI blocked",
    "automation_failed": "Automation failed",
}
REQUIRED = {
    "schema", "persona", "game", "seed", "locale", "large_text", "outcome",
    "stop_reason", "actions", "action_count", "help_count", "attempt_count",
    "mistake_evidence", "points_label", "result_text", "resumed",
    "resume_verified", "replay_started", "utility_action_found",
    "payment_gate_found", "limitations",
}
CELL_RE = re.compile(r"persona-cell-(P[1-7])-([A-Za-z]+)")
IMAGE_SUFFIXES = {".png", ".jpg", ".jpeg", ".webp"}


def read_json(path: Path):
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError):
        return None


def manifest_entries(value):
    if isinstance(value, dict):
        if "exportedFileName" in value:
            yield value
        for nested in value.values():
            yield from manifest_entries(nested)
    elif isinstance(value, list):
        for nested in value:
            yield from manifest_entries(nested)


def trace_objects(value):
    if isinstance(value, dict):
        if all(key in value for key in ("schema", "persona", "game", "actions")):
            yield value
        else:
            for nested in value.values():
                yield from trace_objects(nested)
    elif isinstance(value, list):
        for nested in value:
            yield from trace_objects(nested)


def validate_trace(trace, path):
    if trace["schema"] != 1:
        raise ValueError(f"{path.name}: unsupported trace schema {trace['schema']!r}")
    missing = REQUIRED - trace.keys()
    if missing:
        raise ValueError(f"{path.name}: missing trace fields: {', '.join(sorted(missing))}")
    if trace["persona"] not in PERSONAS:
        raise ValueError(f"{path.name}: unknown persona {trace['persona']!r}")
    if trace["game"] not in GAMES:
        raise ValueError(f"{path.name}: unknown game {trace['game']!r}")
    if trace["outcome"] not in OUTCOMES:
        raise ValueError(f"{path.name}: unknown outcome {trace['outcome']!r}")
    if not isinstance(trace["actions"], list):
        raise ValueError(f"{path.name}: actions must be an ordered list")
    for count in ("action_count", "help_count", "attempt_count"):
        if isinstance(trace[count], bool) or not isinstance(trace[count], int) or trace[count] < 0:
            raise ValueError(f"{path.name}: {count} must be a nonnegative integer")
    for flag in ("large_text", "resumed", "resume_verified", "replay_started", "utility_action_found", "payment_gate_found"):
        if not isinstance(trace[flag], bool):
            raise ValueError(f"{path.name}: {flag} must be a boolean")
    if not isinstance(trace["limitations"], (str, list)):
        raise ValueError(f"{path.name}: limitations must be text or a list")


def load_exports(source):
    aliases = {}
    images = []
    for manifest in sorted(source.rglob("manifest.json")):
        value = read_json(manifest)
        for entry in manifest_entries(value):
            file = manifest.parent / str(entry["exportedFileName"])
            if not file.is_file():
                raise ValueError(f"Manifest references missing attachment: {file}")
            aliases[file.resolve()] = str(entry.get("suggestedHumanReadableName", file.name))
    cells = {}
    for file in sorted(source.rglob("*")):
        if not file.is_file():
            continue
        alias = aliases.get(file.resolve(), file.name)
        if file.suffix.lower() in IMAGE_SUFFIXES:
            match = CELL_RE.search(alias)
            if match:
                images.append((file, alias, match.group(1), match.group(2)))
            continue
        if file.name == "manifest.json" or file.stat().st_size > 10_000_000:
            continue
        # XCTest Data attachments can have UUID names without a .json suffix.
        for trace in trace_objects(read_json(file)):
            validate_trace(trace, file)
            key = (trace["persona"], trace["game"])
            if key in cells:
                raise ValueError(f"Duplicate trace for {key[0]}/{key[1]}: {file.name}")
            cells[key] = (trace, file, alias)
    return cells, images


def safe_name(name):
    return re.sub(r"[^A-Za-z0-9._-]+", "-", name).strip(".-")


def normalize_result_scan(trace):
    """Require an explicitly scoped result scan; labels vary by app locale."""
    cell = dict(trace)
    background_controls = {"watchlist", "explore", "home"}
    inspected_buttons = []
    inspections = []
    for action in trace["actions"]:
        if isinstance(action, dict) and action.get("type") == "result_inspection":
            inspections.append(action)
            inspected_buttons.extend(str(label) for label in action.get("displayed_buttons", []))
    contaminated = any(label.strip().casefold() in background_controls for label in inspected_buttons)
    scoped = bool(inspections) and all(action.get("scope") == "arcade_sheet" for action in inspections)
    unverified = contaminated or not scoped
    cell["result_scan_unverified"] = unverified
    cell["result_scan_scope"] = (
        "app_wide_background_controls_present" if contaminated
        else "arcade_sheet" if scoped
        else "scope_not_recorded"
    )
    if unverified:
        cell["raw_result_scan_flags"] = {
            "utility_action_found": trace["utility_action_found"],
            "payment_gate_found": trace["payment_gate_found"],
        }
        cell["utility_action_found"] = None
        cell["payment_gate_found"] = None
        limitation = (("Result inspection included underlying Home/Explore/Watchlist controls. " if contaminated
                       else "Result inspection was not explicitly scoped to the Arcade sheet. ") +
                      "The scan cannot establish a game-result movie-utility route or payment gate; "
                      "normalized route flags are unknown and original scan flags remain in the raw trace.")
        existing = trace["limitations"]
        cell["limitations"] = list(existing) + [limitation] if isinstance(existing, list) else [existing, limitation]
    for index, action in enumerate(trace["actions"]):
        if (isinstance(action, dict) and action.get("type") == "terminate_relaunch"
                and action.get("terminal_before_interruption") is True):
            before = str(action.get("before", ""))
            points = re.search(r"(?:^|\|)arcade\.points:([^|]*)", before)
            cell["initial_result_before_relaunch"] = {
                "action_index": index + 1,
                "terminal_before_interruption": True,
                "before_signature": before,
                "points_evidence": points.group(1) if points else "No points label captured in the before signature",
                "interpretation": ("An earned practice result was visible before the forced relaunch. "
                                   "The raw outcome records the later path. Completed-practice re-entry intentionally "
                                   "starts fresh; this is not evidence of Daily Mix score loss or a product defect."),
            }
            break
    return cell


def copy_evidence(cells, images, output):
    traces = output / "traces"
    screens = output / "screenshots"
    traces.mkdir(parents=True, exist_ok=True)
    screens.mkdir(parents=True, exist_ok=True)
    normalized = []
    screenshot_names = Counter()
    for persona in PERSONAS:
        for game in GAMES:
            key = (persona, game)
            if key not in cells:
                continue
            trace, source, alias = cells[key]
            cell_id = f"persona-cell-{persona}-{game}"
            dest = traces / f"{cell_id}.json"
            # Preserve the original attachment byte-for-byte, not an invented trace.
            shutil.copyfile(source, dest)
            cell = normalize_result_scan(trace)
            cell.update(cell_id=cell_id, persona_name=PERSONAS[persona], game_name=GAMES[game],
                        trace_file=dest.relative_to(output).as_posix(),
                        source_attachment=source.name, source_suggested_name=alias,
                        screenshots=[])
            for index, (image, image_alias, image_persona, image_game) in enumerate(images):
                if (image_persona, image_game) != key:
                    continue
                # Strip XCTest's generated _N_UUID suffix while retaining start/stop/result.
                stem = Path(image_alias).stem
                stem = re.sub(r"_\d+_[0-9A-Fa-f-]{36}$", "", stem)
                stem = safe_name(stem)
                screenshot_names[stem] += 1
                suffix = f"-{screenshot_names[stem]}" if screenshot_names[stem] > 1 else ""
                name = f"{stem}{suffix}{image.suffix.lower()}"
                target = screens / name
                shutil.copyfile(image, target)
                cell["screenshots"].append({"name": image_alias, "file": target.relative_to(output).as_posix()})
            normalized.append(cell)
    return normalized


def summarized_cells(cells):
    patterns = []
    for game, name in GAMES.items():
        rows = [c for c in cells if c["game"] == game]
        outcomes = Counter(c["outcome"] for c in rows)
        stop_reasons = Counter(str(c["stop_reason"]) for c in rows if c["stop_reason"])
        patterns.append({
            "game": game, "game_name": name, "recorded_cells": len(rows),
            "outcomes": dict(outcomes), "total_actions": sum(c["action_count"] for c in rows),
            "total_help": sum(c["help_count"] for c in rows),
            "total_attempts": sum(c["attempt_count"] for c in rows),
            "resume_verified": sum(c["resume_verified"] is True for c in rows),
            "replay_started": sum(c["replay_started"] is True for c in rows),
            "utility_action_found": None if any(c["result_scan_unverified"] for c in rows) else sum(c["utility_action_found"] is True for c in rows),
            "payment_gate_found": None if any(c["result_scan_unverified"] for c in rows) else sum(c["payment_gate_found"] is True for c in rows),
            "result_scan_unverified": sum(c["result_scan_unverified"] for c in rows),
            "stop_reasons": dict(stop_reasons),
        })
    return patterns


def md_escape(value):
    return str(value).replace("|", "\\|").replace("\n", " ").replace("\r", " ")


def cell_label(cell):
    return (f"{OUTCOMES[cell['outcome']]} · {cell['action_count']} gameplay taps / "
            f"{cell['help_count']} help taps / {cell['attempt_count']} attempt taps · {cell['points_label']}"
            + (" · result scan unverified" if cell.get("result_scan_unverified") else "")
            + (" · earned result before relaunch" if cell.get("initial_result_before_relaunch") else ""))


def write_csv(cells, output):
    by_key = {(cell["persona"], cell["game"]): cell for cell in cells}
    with (output / "comparison.csv").open("w", encoding="utf-8", newline="") as handle:
        writer = csv.writer(handle, lineterminator="\n")
        writer.writerow(["Game"] + [f"{p} {PERSONAS[p]}" for p in PERSONAS])
        for game, name in GAMES.items():
            writer.writerow([name] + [cell_label(by_key[(p, game)]) if (p, game) in by_key else "MISSING EVIDENCE" for p in PERSONAS])
    columns = ["persona", "persona_name", "game", "game_name", "outcome", "stop_reason",
               "action_count", "help_count", "attempt_count", "points_label", "resumed",
               "resume_verified", "replay_started", "utility_action_found", "payment_gate_found",
               "result_scan_unverified", "result_scan_scope", "raw_result_scan_flags", "initial_result_before_relaunch", "trace_file", "screenshot_files", "limitations"]
    with (output / "observations.csv").open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, columns, lineterminator="\n")
        writer.writeheader()
        for cell in cells:
            row = {key: cell.get(key, "") for key in columns}
            row["screenshot_files"] = ";".join(s["file"] for s in cell["screenshots"])
            row["limitations"] = json.dumps(cell["limitations"], ensure_ascii=False)
            row["raw_result_scan_flags"] = json.dumps(cell.get("raw_result_scan_flags", {}), ensure_ascii=False)
            row["initial_result_before_relaunch"] = json.dumps(cell.get("initial_result_before_relaunch", {}), ensure_ascii=False)
            for flag in ("utility_action_found", "payment_gate_found"):
                if cell[flag] is None:
                    row[flag] = "unknown (unverified app-wide result scan)"
            writer.writerow(row)


def write_markdown(cells, missing, patterns, output):
    by_key = {(c["persona"], c["game"]): c for c in cells}
    lines = ["# Arcade persona comparison", "",
             f"**{'PARTIAL' if missing else 'Complete'} assigned simulator evidence: {len(cells)}/70 cells.**",
             "", "These are constrained scripted persona runs. Earned results and policy stops are runtime observations; "
             "they do not establish human fun, voluntary replay, retention or willingness to pay. "
             "Counts record runner gameplay tap attempts and their help/attempt categories; they are not successful-state-change counts, human speed or difficulty measurements.", "",
             "Each cell: outcome · gameplay taps / help taps / attempt taps · recorded points. "
             "Trace links preserve exact actions, result text, stop reasons and limitations.", "",
             "| Game | " + " | ".join(f"{p} {PERSONAS[p]}" for p in PERSONAS) + " |",
             "| --- | " + " | ".join("---" for _ in PERSONAS) + " |"]
    for game, name in GAMES.items():
        row = [md_escape(name)]
        for persona in PERSONAS:
            cell = by_key.get((persona, game))
            row.append(f"[{md_escape(cell_label(cell))}]({cell['trace_file']})" if cell else "**Missing evidence**")
        lines.append("| " + " | ".join(row) + " |")
    lines.extend(["", "## Mechanically observed patterns by game", ""])
    for pattern in patterns:
        outcomes = "; ".join(f"{OUTCOMES[key]} {count}" for key, count in pattern["outcomes"].items()) or "No recorded outcomes"
        lines.append(f"- **{pattern['game_name']}**: {pattern['recorded_cells']}/7 traces; {outcomes}. "
                     f"Recorded totals: {pattern['total_actions']} gameplay taps, {pattern['total_help']} help taps, "
                     f"{pattern['total_attempts']} attempt taps. Resume verified in {pattern['resume_verified']} traces; "
                     f"scripted replay started in {pattern['replay_started']}. "
                     + (f"Result utility/payment scan unverified in {pattern['result_scan_unverified']} traces; "
                        "raw app-wide scan flags do not establish game-result routes."
                        if pattern["result_scan_unverified"] else
                        f"Unverified result scans: 0. Recorded scan positives: utility {pattern['utility_action_found']}; "
                        f"payment {pattern['payment_gate_found']} (scan flags, not independently verified routes)."))
        for reason, count in pattern["stop_reasons"].items():
            lines.append(f"  - Recorded stop ({count}): {md_escape(reason)}")
    if missing:
        lines.extend(["", "## Missing cells", ""] + [f"- {p}/{g}" for p, g in missing])
    lines.extend(["", "[Open the interactive comparison](index.html). Raw observations are also in [cells.json](cells.json) "
                  "and [comparison.csv](comparison.csv).", ""])
    (output / "comparison.md").write_text("\n".join(lines), encoding="utf-8")


def write_html(payload, output):
    data = json.dumps(payload, ensure_ascii=False).replace("<", "\\u003c").replace(">", "\\u003e").replace("&", "\\u0026")
    document = r'''<!doctype html>
<html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>Arcade persona comparison</title>
<style>
:root{font-family:system-ui,sans-serif;color:#172033;background:#f5f7fb}body{margin:0;padding:24px;line-height:1.45}main{max-width:1500px;margin:auto}h1{margin-bottom:8px}.notice{background:#fff3cf;border-left:4px solid #9c6500;padding:14px}a{color:#174b99}.controls{display:flex;gap:16px;flex-wrap:wrap;margin:20px 0}label{display:flex;flex-direction:column;gap:4px}select,button{font:inherit;padding:8px;border:1px solid #97a3b8;border-radius:6px;background:white}button{cursor:pointer}button:focus-visible,a:focus-visible,select:focus-visible{outline:3px solid #255dd8;outline-offset:3px}.scroll{overflow:auto}table{border-collapse:collapse;background:white;width:100%;min-width:1000px}th,td{border:1px solid #d1d9e5;padding:10px;text-align:left;vertical-align:top}thead th{background:#e6edf8}tbody th{min-width:140px}td button{width:100%;min-height:100px;text-align:left}.earned{border-left:5px solid #26813b}.earned_with_help{border-left:5px solid #166887}.revealed_after_stop{border-left:5px solid #bd8100}.ui_blocked,.automation_failed{border-left:5px solid #b22d3a}.small{display:block;font-size:.85rem;color:#45516a;margin-top:5px}.missing{color:#794720;font-weight:600}dialog{border:0;border-radius:14px;width:min(1000px,90vw);max-height:85vh;padding:24px;box-shadow:0 12px 50px #0005}dialog::backdrop{background:#17203399}.close{float:right}.fields{display:grid;grid-template-columns:180px 1fr;gap:8px}.fields dt{font-weight:600}.fields dd{margin:0;white-space:pre-wrap;overflow-wrap:anywhere}pre{white-space:pre-wrap;overflow-wrap:anywhere;background:#f1f4f8;padding:14px}.screens{display:flex;gap:16px;flex-wrap:wrap}.screens figure{margin:0;max-width:230px}.screens img{width:100%;height:auto}.screens figcaption{font-size:.8rem;overflow-wrap:anywhere}#patterns article{background:#fff;padding:14px;margin:10px 0;border:1px solid #d1d9e5;border-radius:8px}@media(max-width:600px){body{padding:12px}.fields{grid-template-columns:1fr}.fields dd{margin-bottom:8px}}
</style><main><h1>Arcade persona comparison</h1><p id="coverage"></p>
<p class="notice">Assigned, scripted simulator play. This evidence does not establish human enjoyment, voluntary replay, retention or purchase intent. Counts record runner gameplay tap attempts and help/attempt categories; they do not measure successful state changes, human speed or difficulty. Open any cell for the exact trace, policy stop, result and limitations.</p>
<p><a href="comparison.csv" download>Download grid CSV</a> · <a href="observations.csv" download>Download full observations CSV</a> · <a href="comparison.md">Markdown grid</a> · <a href="cells.json">Normalized observations</a></p>
<div class="controls"><label>Persona<select id="persona"><option value="">All seven</option></select></label><label>Game<select id="game"><option value="">All ten</option></select></label><label>Recorded outcome<select id="outcome"><option value="">All outcomes</option></select></label></div>
<p id="filter-summary" role="status" aria-live="polite"></p><div class="scroll"><table id="grid"><caption>Rows are games; columns are reference personas. Each button opens runtime evidence.</caption><thead></thead><tbody></tbody></table></div>
<h2>Mechanically recorded patterns</h2><section id="patterns"></section>
<dialog id="details" aria-labelledby="detail-title"><button class="close" id="close">Close details</button><h2 id="detail-title"></h2><p id="detail-outcome"></p><p id="trace-link"></p><dl class="fields" id="fields"></dl><h3>Exact ordered actions</h3><ol id="actions"></ol><h3>Screenshots</h3><div id="screens" class="screens"></div></dialog>
<script id="data" type="application/json">__DATA__</script><script>
'use strict';
const data=JSON.parse(document.getElementById('data').textContent), byKey=new Map(data.cells.map(c=>[c.persona+'/'+c.game,c])), d=document.getElementById('details');
const labels=data.outcome_labels, fields=['declared_prior_titles','runtime_seconds','seed','locale','large_text','stop_reason','action_count','help_count','attempt_count','mistake_evidence','points_label','result_text','resumed','resume_verified','replay_started','utility_action_found','payment_gate_found','result_scan_unverified','result_scan_scope','raw_result_scan_flags','initial_result_before_relaunch','limitations'];
function el(tag,text){const node=document.createElement(tag);if(text!==undefined)node.textContent=text;return node}
function fmt(v){return v===null?'Unknown — unverified result scan':typeof v==='string'?v:JSON.stringify(v,null,2)}
for(const [key,name] of Object.entries(data.personas)){const o=el('option',key+' '+name);o.value=key;document.getElementById('persona').append(o)}
for(const [key,name] of Object.entries(data.games)){const o=el('option',name);o.value=key;document.getElementById('game').append(o)}
for(const [key,name] of Object.entries(labels)){const o=el('option',name);o.value=key;document.getElementById('outcome').append(o)}
document.getElementById('coverage').textContent=(data.missing.length?'PARTIAL':'Complete')+' evidence: '+data.cells.length+'/70 unique cells.';
function openCell(c){document.getElementById('detail-title').textContent=c.game_name+' · '+c.persona+' '+c.persona_name;document.getElementById('detail-outcome').textContent=labels[c.outcome];const link=el('a','Original runtime trace JSON');link.href=c.trace_file;document.getElementById('trace-link').replaceChildren(link);const fs=document.getElementById('fields');fs.replaceChildren();for(const key of fields){if(Object.hasOwn(c,key))fs.append(el('dt',({runtime_seconds:'Automation runtime seconds',action_count:'Runner gameplay taps',help_count:'Runner help taps',attempt_count:'Runner attempt taps'})[key]||key.replaceAll('_',' ')),el('dd',fmt(c[key])));}const acts=document.getElementById('actions');acts.replaceChildren();for(const action of c.actions){const li=el('li');li.append(el('pre',fmt(action)));acts.append(li)}if(!c.actions.length)acts.append(el('li','No gameplay actions recorded.'));const ss=document.getElementById('screens');ss.replaceChildren();for(const screen of c.screenshots){const f=el('figure'),a=el('a'),im=el('img');a.href=screen.file;a.target='_blank';a.rel='noopener';im.src=screen.file;im.alt=screen.name;a.append(im);f.append(a,el('figcaption',screen.name));ss.append(f)}if(!c.screenshots.length)ss.append(el('p','No screenshot attachments were exported for this cell.'));d.showModal()}
document.getElementById('close').onclick=()=>d.close();
function render(){const p=document.getElementById('persona').value,g=document.getElementById('game').value,o=document.getElementById('outcome').value,ps=Object.keys(data.personas).filter(k=>!p||k===p),gs=Object.keys(data.games).filter(k=>!g||k===g);const header=el('tr');header.append(el('th','Game'));for(const id of ps){const th=el('th',id+' '+data.personas[id]);th.scope='col';header.append(th)}document.querySelector('#grid thead').replaceChildren(header);const body=document.querySelector('#grid tbody');body.replaceChildren();let shown=0;for(const id of gs){const tr=el('tr'),th=el('th',data.games[id]);th.scope='row';tr.append(th);for(const pid of ps){const td=el('td'),c=byKey.get(pid+'/'+id);if(!c){td.className='missing';td.textContent='Missing evidence'}else if(o&&c.outcome!==o){td.textContent='Filtered out'}else{shown++;const b=el('button',labels[c.outcome]);b.className=c.outcome;b.append(el('span',c.action_count+' gameplay taps · '+c.help_count+' help taps · '+c.attempt_count+' attempt taps'),el('span',c.points_label||'No points label'));if(c.result_scan_unverified)b.append(el('span','Result scan unverified'));if(c.initial_result_before_relaunch)b.append(el('span','Earned result before relaunch'));for(const span of b.querySelectorAll('span'))span.className='small';b.setAttribute('aria-label',pid+' '+c.game_name+': '+labels[c.outcome]+'. Open runtime evidence');b.onclick=()=>openCell(c);td.append(b)}tr.append(td)}body.append(tr)}document.getElementById('filter-summary').textContent=shown+' recorded cells shown.'}
for(const id of ['persona','game','outcome'])document.getElementById(id).onchange=render;render();
for(const p of data.patterns){const article=el('article');article.append(el('h3',p.game_name),el('p',p.recorded_cells+'/7 traces; '+Object.entries(p.outcomes).map(([k,n])=>labels[k]+': '+n).join('; ')+'. Recorded totals: '+p.total_actions+' gameplay taps, '+p.total_help+' help taps, '+p.total_attempts+' attempt taps.'),el('p','Verified resume: '+p.resume_verified+'; scripted replay started: '+p.replay_started+'. '+(p.result_scan_unverified?'Result utility/payment scan unverified in '+p.result_scan_unverified+' traces; raw app-wide scan flags do not establish game-result routes.':'Unverified result scans: 0. Recorded scan positives: utility '+p.utility_action_found+'; payment '+p.payment_gate_found+' (scan flags, not independently verified routes).')));if(Object.keys(p.stop_reasons).length){const ul=el('ul');for(const [reason,count] of Object.entries(p.stop_reasons))ul.append(el('li','Recorded stop ('+count+'): '+reason));article.append(ul)}document.getElementById('patterns').append(article)}
</script></main></html>'''
    (output / "index.html").write_text(document.replace("__DATA__", data), encoding="utf-8")


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", type=Path, required=True, help="Directory of xcresulttool-exported attachments")
    parser.add_argument("--output", type=Path, required=True, help="Standalone evidence/grid destination")
    parser.add_argument("--allow-partial", action="store_true", help="Explicitly generate a labeled incomplete grid")
    args = parser.parse_args(argv)
    source, output = args.input.resolve(), args.output.resolve()
    if not source.is_dir():
        parser.error("--input must be an existing directory")
    if output == source or source in output.parents or output in source.parents:
        parser.error("Input and output directories must not contain one another")
    try:
        cells, images = load_exports(source)
        missing = [(p, g) for g in GAMES for p in PERSONAS if (p, g) not in cells]
        if missing and not args.allow_partial:
            raise ValueError(f"Only {len(cells)}/70 unique cells; missing " + ", ".join(f"{p}/{g}" for p, g in missing) + ". Use --allow-partial only to publish explicitly incomplete evidence.")
        output.mkdir(parents=True, exist_ok=True)
        normalized = copy_evidence(cells, images, output)
        patterns = summarized_cells(normalized)
        payload = {"schema": 1, "evidence_type": "assigned simulator persona traces",
                   "complete": not missing, "expected_cells": 70, "recorded_cells": len(normalized),
                   "result_scan_unverified": sum(cell["result_scan_unverified"] for cell in normalized),
                   "personas": PERSONAS, "games": GAMES, "outcome_labels": OUTCOMES,
                   "missing": [{"persona": p, "game": g} for p, g in missing],
                   "cells": normalized, "patterns": patterns}
        (output / "cells.json").write_text(json.dumps(payload, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
        write_csv(normalized, output)
        write_markdown(normalized, missing, patterns, output)
        write_html(payload, output)
        print(json.dumps({"complete": not missing, "cells": len(normalized), "expected": 70,
                          "screenshots": sum(len(c["screenshots"]) for c in normalized),
                          "result_scan_unverified": payload["result_scan_unverified"],
                          "outcomes": dict(Counter(c["outcome"] for c in normalized)),
                          "output": str(output)}, ensure_ascii=False))
        return 0
    except (ValueError, OSError) as error:
        print(f"Error: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
