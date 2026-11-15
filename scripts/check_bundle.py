"""Check the built product, not only Xcode's build settings."""
from pathlib import Path
import plistlib
import sys
app = Path(sys.argv[1])
with (app/'Info.plist').open('rb') as stream:
    info = plistlib.load(stream)
assert info.get('CFBundleIdentifier') == 'com.ningfeng.HanziSprout', info
assert info.get('CFBundlePackageType') == 'APPL', info
assert info.get('CFBundleExecutable') and (app/info['CFBundleExecutable']).is_file(), info
assert set(info.get('UIDeviceFamily', [])) == {1, 2}, info
assert info.get('NSMicrophoneUsageDescription') and info.get('NSSpeechRecognitionUsageDescription'), info
assert (app/'Resources/writer.html').is_file()
assert len(list((app/'Resources/Strokes').glob('*.json'))) >= 9500
print('Built app identity, executable, device families, permissions and offline resources verified')
