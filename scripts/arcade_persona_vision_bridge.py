#!/usr/bin/env python3
"""Forward inspected image judgments to fixture-only simulator request files.

Reads one JSON line per decision from stdin. This never chooses an answer: the
caller must inspect the fresh request screenshot and supply title+basis or stop.
"""
import json
import re
import sys
from pathlib import Path

BASE = Path('/Users/johndlugokecki/Library/Developer/CoreSimulator/Devices/54589BE9-B7F0-4E11-890E-E437D7D446EB/data/Containers/Data/Application').resolve()
PATTERN = re.compile(r'^persona-cell-P[1-7]-[A-Za-z]+-[A-Za-z0-9-]+-request\.json$')
print('Fixture vision bridge ready; decisions only, maximum 100 replies.', flush=True)
for number, line in enumerate(sys.stdin, 1):
    if number > 100:
        break
    try:
        command = json.loads(line)
        request_path = Path(command['request_path']).resolve()
        relative = request_path.relative_to(BASE)
        if len(relative.parts) != 4 or relative.parts[1:3] != ('tmp', 'arcade-persona-live') or not PATTERN.fullmatch(request_path.name):
            raise ValueError('Not an authorized temporary persona fixture request')
        request = json.loads(request_path.read_text())
        reply_path = Path(request['reply_path']).resolve()
        if reply_path.parent != request_path.parent or reply_path.name != request_path.name.replace('-request.json', '-reply.json'):
            raise ValueError('Unexpected fixture reply path')
        if 'stop_reason' in command:
            reply = {'stop_reason': command['stop_reason']}
        else:
            title, basis = command['title'], command['basis']
            if title not in request['displayed_choices'] or title not in request['permitted_prior_titles'] or not basis.strip():
                raise ValueError('Judgment must name a displayed familiar title and visual basis')
            reply = {'title': title, 'basis': basis}
        reply_path.write_text(json.dumps(reply))
        print(json.dumps({'saved': request['request_id']}), flush=True)
    except Exception as error:
        print(json.dumps({'error': str(error)}), flush=True)
