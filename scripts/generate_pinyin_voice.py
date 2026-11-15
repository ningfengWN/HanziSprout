"""Developer-only: pip install pypinyin==0.55.0. No runtime dependency."""
from pathlib import Path
import json
from pypinyin import pinyin, Style
root = Path(__file__).resolve().parents[1]
assets = root/'HanziSprout/LearningAssets'
index = {}
# Prefer familiar single-reading characters, then use the bundled stroke repertoire.
common = '妈妈爸爸我你他她它的了是有和在花天开心小大多少上下左右春夏秋冬山水日月风雨雪云鸟鱼虫马牛羊木树林叶草公园朋友老师学校书本爱家人字写读听说看手口耳目心田白红黄蓝黑绿青早晚太阳星光蝴蝶纸笔快乐学习世界故事'
characters = list(common) + sorted(p.stem for p in (assets/'Strokes').glob('*.json'))
for character in characters:
    readings = pinyin(character, style=Style.TONE, heteronym=True, strict=True)[0]
    if len(readings) == 1 and readings[0] != character:
        index.setdefault(readings[0], character)
# Common unambiguous spoken representatives for polyphonic lessons.
index.update({'háng':'杭', 'xíng':'形', 'zhòng':'众', 'chóng':'虫', 'lǜ':'律', 'lǘ':'驴', 'nǚ':'女', 'dié':'叠', 'de':'的', 'le':'了', 'ma':'吗'})
(assets/'PinyinVoice.json').write_text(json.dumps(index, ensure_ascii=False, sort_keys=True, indent=2)+'\n')
print(f'{len(index)} tone-marked syllables mapped to spoken homophones')
