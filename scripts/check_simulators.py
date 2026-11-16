"""Install and launch the built app on available iPhone AND iPad simulators."""
import json
import plistlib
from pathlib import Path
import subprocess
import sys
import time

def run(*args):
    return subprocess.check_output(args, text=True).strip()
app = str(Path(sys.argv[1]).resolve())
with (Path(app)/'Info.plist').open('rb') as stream:
    bundle = plistlib.load(stream)['CFBundleIdentifier']
assert bundle and '$(' not in bundle
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
        run('xcrun', 'simctl', 'ui', udid, 'appearance', 'dark')
        run('xcrun', 'simctl', 'install', udid, app)
        print(run('xcrun', 'simctl', 'launch', udid, bundle), flush=True)
        time.sleep(3)
        run('xcrun', 'simctl', 'io', udid, 'screenshot', f'Home-{family}.png')
        print(f"Installed and launched on {device['name']} with system dark appearance", flush=True)
        run('xcrun', 'simctl', 'terminate', udid, bundle)
    finally:
        if booted_here:
            run('xcrun', 'simctl', 'shutdown', udid)
