
let all = PinyinLesson.exercises
assert(all.count > 1000)
assert(Set(all.map(\.id)).count == all.count)
assert(PinyinLesson.items(group: 1).count > 100)
assert(PinyinLesson.items(group: 2).count > 100)
for item in PinyinLesson.starterExercises {
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

assert(PinyinLesson.initial(for: "chuāng") == "ch")
assert(PinyinLesson.final(for: "chuāng") == "uang")
assert(PinyinLesson.final(for: "qù") == "ü")
assert(PinyinLesson.final(for: "jūn") == "ün")
for item in all {
    let choices = PinyinLesson.choices(for: item, group: 0)
    assert(choices.count <= 6 && choices.contains(where: { $0.id == item.id }))
    assert(Set(choices.map(\.id)).count == choices.count)
    assert(!PinyinLesson.demonstration(for: item).isEmpty)
}
