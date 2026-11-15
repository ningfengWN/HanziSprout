"""Install and launch the built app on available iPhone AND iPad simulators."""
import json
from pathlib import Path
import subprocess
import sys

def run(*args):
    return subprocess.check_output(args, text=True).strip()
app = str(Path(sys.argv[1]).resolve())
devices = json.loads(run('xcrun', 'simctl', 'list', 'devices', 'available', '--json'))['devices']
for family in ('iPhone', 'iPad'):
    matches = [device for runtime, group in devices.items() if '.iOS-' in runtime
               for device in group if device.get('isAvailable') and device['name'].startswith(family)]
    assert matches, f'No available {family} simulator'
    device = matches[0]
    udid = device['udid']
    booted_here = device['state'] != 'Booted'
    try:
        if booted_here:
            run('xcrun', 'simctl', 'boot', udid)
        run('xcrun', 'simctl', 'bootstatus', udid, '-b')
        run('xcrun', 'simctl', 'install', udid, app)
        print(run('xcrun', 'simctl', 'launch', udid, 'com.ningfeng.HanziSprout'), flush=True)
        print(f"Installed and launched on {device['name']}", flush=True)
        run('xcrun', 'simctl', 'terminate', udid, 'com.ningfeng.HanziSprout')
    finally:
        if booted_here:
            run('xcrun', 'simctl', 'shutdown', udid)
