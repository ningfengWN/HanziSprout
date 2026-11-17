
let all = PinyinLesson.exercises
assert(all.count == 10)
assert(Set(all.map(\.id)).count == 10)
assert(PinyinLesson.items(group: 0).count == 4)
assert(PinyinLesson.items(group: 1).count == 6)
for item in all {
    assert(PinyinLesson.transcription(item.word, matches: item), item.id)
    assert(PinyinLesson.transcription(item.pinyin, matches: item))
    assert(!PinyinLesson.transcription("我说" + item.word, matches: item))
    assert(!PinyinLesson.transcription("", matches: item))
}
let ba = all[0]
assert(PinyinLesson.transcription("八。", matches: ba))
assert(!PinyinLesson.transcription("爸", matches: ba))
assert(!PinyinLesson.transcription("趴", matches: ba))
print("Pinyin lesson checks passed")
