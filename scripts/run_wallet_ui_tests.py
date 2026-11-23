#!/usr/bin/env python3
"""Run only on an ephemeral CI simulator with synthetic wallet data."""
import json
import os
from pathlib import Path
import signal
import subprocess
import time

if os.environ.get('CI') != 'true':
    raise SystemExit('This fixture-writing script is restricted to ephemeral CI simulators.')

def run(*args, **kwargs):
    return subprocess.run(args, check=True, **kwargs)

raw = subprocess.check_output(['xcrun', 'simctl', 'list', 'devices', 'available', '--json'])
devices = [d for runtime, rows in json.loads(raw)['devices'].items() if 'iOS' in runtime for d in rows]
phone = next(d for d in devices if 'iPhone' in d['name'])
tablet = next(d for d in devices if 'iPad' in d['name'])
flags = ['CODE_SIGNING_ALLOWED=NO', 'CODE_SIGNING_REQUIRED=NO', 'CODE_SIGN_IDENTITY=']
out = Path('ui-results'); out.mkdir(exist_ok=True)
ids = [f'00000000-0000-0000-0000-{i+1:012d}' for i in range(6)]
tones = ['코발트', '에메랄드', '바이올렛', '코랄', '코발트', '에메랄드']
for label, device in [('compact', phone), ('wide', tablet)]:
    udid = device['udid']
    print('UI smoke device:', label, device['name'], flush=True)
    destination = f'platform=iOS Simulator,id={udid}'
    run('xcodebuild', '-project', 'PocketLedger.xcodeproj', '-scheme', 'PocketLedger',
        '-configuration', 'Debug', '-sdk', 'iphonesimulator', '-destination', destination,
        '-derivedDataPath', 'simulator-build', *flags, 'build-for-testing')
    if device['state'] != 'Booted': run('xcrun', 'simctl', 'boot', udid)
    run('xcrun', 'simctl', 'bootstatus', udid, '-b')
    run('xcrun', 'simctl', 'install', udid, 'simulator-build/Build/Products/Debug-iphonesimulator/PocketLedger.app')
    container = Path(subprocess.check_output(['xcrun', 'simctl', 'get_app_container', udid, 'com.example.pocketledger', 'data']).decode().strip())
    fixture = {'cards': [dict(id=identity, name=f'Demo Card {i+1}', issuer='Demo Bank', lastFour=f'{i+1:04d}', tone=tones[i], spendingLimit=0) for i, identity in enumerate(ids)], 'appLockEnabled': False}
    ledger = container / 'Documents/ledger-data.json'
    ledger.parent.mkdir(exist_ok=True)
    ledger.write_text(json.dumps(fixture))
    movie = subprocess.Popen(['xcrun', 'simctl', 'io', udid, 'recordVideo', str(out / f'{label}.mp4')])
    try:
        run('xcodebuild', '-project', 'PocketLedger.xcodeproj', '-scheme', 'PocketLedger',
            '-configuration', 'Debug', '-destination', destination, '-derivedDataPath', 'simulator-build',
            '-resultBundlePath', str(out / f'{label}.xcresult'), '-parallel-testing-enabled', 'NO',
            *flags, 'test-without-building')
        actual = [x['id'].lower() for x in json.loads(ledger.read_text())['cards']]
        assert actual == [x.lower() for x in ids], 'Browsing or returning changed saved card order'
        print('UI passed and persisted order unchanged:', label, flush=True)
    finally:
        movie.send_signal(signal.SIGINT)
        movie.wait(timeout=30)
        run('xcrun', 'simctl', 'shutdown', udid)
