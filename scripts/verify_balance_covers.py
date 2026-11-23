#!/usr/bin/env python3
"""Check original artwork and, in CI, the compiled asset-catalog names."""
import argparse
import hashlib
import json
from pathlib import Path
import struct
import subprocess

root = Path(__file__).resolve().parent.parent
parser = argparse.ArgumentParser()
parser.add_argument('--app', type=Path)
args = parser.parse_args()
manifest = json.loads((root / 'scripts/balance-cover-sha256.json').read_text())
for code, sha256 in manifest.items():
    imageset = root / 'PocketLedger/Assets.xcassets' / f'balance-cover-{code}.imageset'
    entries = json.loads((imageset / 'Contents.json').read_text())['images']
    data = (imageset / next(entry['filename'] for entry in entries if 'filename' in entry)).read_bytes()
    assert data[:8] == b'\x89PNG\r\n\x1a\n', f'{code}: invalid PNG'
    assert struct.unpack('>II', data[16:24]) == (2240, 1000), f'{code}: dimensions changed'
    assert hashlib.sha256(data).hexdigest() == sha256, f'{code}: original bytes changed'
if args.app:
    catalog = args.app / 'Assets.car'
    info = json.loads(subprocess.check_output(['xcrun', 'assetutil', '--info', str(catalog)]))
    names = {entry.get('Name') for entry in info}
    for code in manifest:
        assert f'balance-cover-{code}' in names, f'{code}: missing from compiled app'
print('Four original balance covers verified' + (' in compiled Assets.car' if args.app else ' in source'))
