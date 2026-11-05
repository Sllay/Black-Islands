#!/usr/bin/env python3
"""Offline verification of pinned, Git-owned GDExtension payloads. Never installs."""
import hashlib
import json
import re
import sys
from pathlib import Path

root = Path(__file__).resolve().parents[1]
manifest = json.loads((root / 'scripts/tooling/runtime_dependencies.json').read_text())
pins = dict(re.findall(r'^(\w+)="([^"]+)"', (root / 'scripts/tooling/versions.env').read_text(), re.M))
failed = []
for dependency in manifest['dependencies']:
    pin = pins['VOXEL_TOOLS_SHA256' if dependency['addon'] == 'zylann.voxel' else 'LIMBOAI_SHA256']
    if pin != dependency['archive_sha256']:
        failed.append(dependency['addon'] + ': archive pin mismatch')
    for record in dependency['files']:
        path = root / record['path']
        # Godot legitimately regenerates editor-variant import metadata. Payload
        # binaries, descriptors, licenses and source resources stay byte-checked.
        if not path.is_file() or (path.suffix != '.import' and hashlib.sha256(path.read_bytes()).hexdigest() != record['sha256']):
            failed.append(record['path'])
    print(dependency['addon'], 'bytes=', dependency['total_bytes'], 'files=', len(dependency['files']))
if failed:
    print('RUNTIME_DEPENDENCIES FAIL: restore these files from Git:', *failed, sep='\n', file=sys.stderr)
    sys.exit(1)
print('RUNTIME_DEPENDENCIES PASS (offline; no stamps/downloads)')
