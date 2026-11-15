from pathlib import Path
import json
root = Path(__file__).resolve().parents[1]/'HanziSprout/LearningAssets/Strokes'
paths = list(root.glob('*.json'))
assert len(paths) >= 9500
for path in paths:
    data = json.loads(path.read_text())
    assert data['strokes'] and len(data['strokes']) == len(data['medians']), path
    assert all(len(line) >= 2 for line in data['medians']), path
for char in '蝴蝶今天很开心我和妈妈去公园':
    assert (root/(char+'.json')).exists(), char
print(f'Validated {len(paths)} offline characters')

voice = json.loads((root.parent/'PinyinVoice.json').read_text())
assert len(voice) >= 1000
for syllable, word in {'háng':'杭','xíng':'形','dié':'叠','lǜ':'律'}.items():
    assert voice[syllable] == word
print('Pinyin pronunciation index verified')
