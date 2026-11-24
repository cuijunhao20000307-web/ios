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
    print('STEP:', ' '.join(args), flush=True)
    kwargs.setdefault('timeout', 300 if args[0] == 'xcodebuild' else 120)
    return subprocess.run(args, check=True, **kwargs)

raw = subprocess.check_output(['xcrun', 'simctl', 'list', 'devices', 'available', '--json'])
devices = [d for runtime, rows in json.loads(raw)['devices'].items() if 'iOS' in runtime for d in rows]
phone = next(d for d in devices if 'iPhone' in d['name'])
tablet = next(d for d in devices if 'iPad' in d['name'])
flags = ['CODE_SIGNING_ALLOWED=NO', 'CODE_SIGNING_REQUIRED=NO', 'CODE_SIGN_IDENTITY=', 'ONLY_ACTIVE_ARCH=YES']
out = Path('ui-results'); out.mkdir(exist_ok=True)
ids = [f'00000000-0000-0000-0000-{i+1:012d}' for i in range(6)]
tones = ['코발트', '에메랄드', '바이올렛', '코랄', '코발트', '에메랄드']
for label, device in [('compact', phone), ('wide', tablet)]:
    udid = device['udid']
    print('UI smoke device:', label, device['name'], flush=True)
    destination = f'platform=iOS Simulator,id={udid}'
    if device['state'] != 'Booted': run('xcrun', 'simctl', 'boot', udid)
    run('xcodebuild', '-project', 'PocketLedger.xcodeproj', '-scheme', 'PocketLedger',
        '-configuration', 'Debug', '-sdk', 'iphonesimulator', '-destination', destination,
        '-derivedDataPath', 'simulator-build', *flags, 'build-for-testing')
    run('xcrun', 'simctl', 'bootstatus', udid, '-b')
    run('xcrun', 'simctl', 'install', udid, 'simulator-build/Build/Products/Debug-iphonesimulator/PocketLedger.app')
    container = Path(subprocess.check_output(['xcrun', 'simctl', 'get_app_container', udid, 'com.example.pocketledger', 'data']).decode().strip())
    fixture = {'cards': [dict(id=identity, name=f'Demo Card {i+1}', issuer='Demo Bank', lastFour=f'{i+1:04d}', tone=tones[i], spendingLimit=0) for i, identity in enumerate(ids)], 'appLockEnabled': False}
    ledger = container / 'Documents/ledger-data.json'
    ledger.parent.mkdir(exist_ok=True)
    ledger.write_text(json.dumps(fixture))
    # Prove the test starts with exactly the expected fixture. XCTest may
    # reinstall/replace the application container during teardown, so this
    # original absolute container path must not be assumed valid afterward.
    seeded = json.loads(ledger.read_text())
    assert [card['id'].lower() for card in seeded['cards']] == [item.lower() for item in ids]
    movie = subprocess.Popen(['xcrun', 'simctl', 'io', udid, 'recordVideo', str(out / f'{label}.mp4')])
    try:
        run('xcodebuild', '-project', 'PocketLedger.xcodeproj', '-scheme', 'PocketLedger',
            '-configuration', 'Debug', '-destination', destination, '-derivedDataPath', 'simulator-build',
            '-resultBundlePath', str(out / f'{label}.xcresult'), '-parallel-testing-enabled', 'NO',
            *flags, 'test-without-building')
        # UI tests assert all six visible card identities and their order
        # after browsing/opening/closing, while the app is still running.
        # XCTest teardown can replace or delete its app container. Resolve the
        # active container again instead of reading a stale pre-test path.
        try:
            active = Path(subprocess.check_output([
                'xcrun', 'simctl', 'get_app_container', udid,
                'com.example.pocketledger', 'data'
            ], text=True).strip())
            saved = active / 'Documents/ledger-data.json'
        except subprocess.CalledProcessError:
            saved = None
        if saved is not None and saved.is_file():
            actual = [card['id'].lower() for card in json.loads(saved.read_text())['cards']]
            assert actual == [item.lower() for item in ids], 'Browsing or returning changed saved card order'
            print('UI passed; current container card IDs unchanged:', label, flush=True)
        else:
            print('UI passed; XCTest replaced/removed the app container at teardown.',
                  'In-test card identity/order checks passed; post-test disk check unavailable:',
                  label, flush=True)
    finally:
        movie.send_signal(signal.SIGINT)
        movie.wait(timeout=30)
        run('xcrun', 'simctl', 'shutdown', udid)
