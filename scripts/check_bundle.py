"""Check the built product, not only Xcode's build settings."""
from pathlib import Path
import plistlib
import sys
import re
app = Path(sys.argv[1])
with (app/'Info.plist').open('rb') as stream:
    info = plistlib.load(stream)
bundle = info.get('CFBundleIdentifier', '')
assert re.fullmatch(r'[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)+', bundle), info
project = (Path(__file__).resolve().parents[1]/'HanziSprout.xcodeproj/project.pbxproj').read_text()
configured = re.findall(r'PRODUCT_BUNDLE_IDENTIFIER = "?([^;"\s]+)"?;', project)
assert bundle in configured, f'Built bundle {bundle} differs from project configuration'
assert info.get('CFBundlePackageType') == 'APPL', info
assert info.get('CFBundleExecutable') and (app/info['CFBundleExecutable']).is_file(), info
assert set(info.get('UIDeviceFamily', [])) == {1, 2}, info
assert info.get('NSMicrophoneUsageDescription') and info.get('NSSpeechRecognitionUsageDescription'), info
assert not (app/'Resources').exists(), 'Reserved root Resources directory breaks iOS bundle detection'
assert not (app/'Contents').exists(), 'macOS bundle layout is not valid for this iOS app'
assert (app/'LearningAssets/writer.html').is_file()
assert len(list((app/'LearningAssets/Strokes').glob('*.json'))) >= 9500
print('Built app identity, executable, device families, permissions and offline resources verified')

assert (app/'Assets.car').is_file(), 'Compiled asset catalog is missing'
assert info.get('CFBundleIcons', {}).get('CFBundlePrimaryIcon', {}).get('CFBundleIconName') == 'AppIcon', info
print('AppIcon catalog and bundle icon registration verified')

for name in ['EnglishPhrases', 'EnglishCorrections']:
    assert (app/f'LearningAssets/{name}.json').is_file()
print('Offline English phrase and correction catalogs verified')
