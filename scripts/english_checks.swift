let root = URL(fileURLWithPath: CommandLine.arguments[1])
let phrases = try JSONDecoder().decode([EnglishPhrase].self, from: Data(contentsOf: root.appendingPathComponent("EnglishPhrases.json")))
let corrections = try JSONDecoder().decode([EnglishCorrection].self, from: Data(contentsOf: root.appendingPathComponent("EnglishCorrections.json")))
let catalog = EnglishCatalog(phrases: phrases, corrections: corrections)
assert(phrases.count == 62 && corrections.count == 12)
assert(Set(phrases.map(\.id)).count == phrases.count)
assert(catalog.scenes.count == 8)
if case .phrase(let item) = catalog.lookup("我想喝水！", direction: .toEnglish) {
    assert(item.english == "I'd like some water.")
} else { fatalError("Chinese lookup failed") }
if case .phrase(let item) = catalog.lookup(" I AM HUNGRY! ", direction: .toChinese) {
    assert(item.chinese == "我饿了。")
} else { fatalError("English alias failed") }
assert(EnglishCatalog.normalized("I’m ready!") == EnglishCatalog.normalized("I'm ready."))
assert(EnglishCatalog.normalized("now here") != EnglishCatalog.normalized("nowhere"))
for correction in corrections {
    assert(catalog.lookup(correction.original, direction: .toChinese) == .correction(correction))
}
assert(catalog.lookup("Yesterday I go to the park.", direction: .toEnglish) == .missing)
assert(catalog.lookup("The dragon dances beside Jupiter.", direction: .toChinese) == .missing)
assert(catalog.lookup("", direction: .toEnglish) == .missing)
assert(catalog.lookup("w", direction: .toChinese) == .missing)
if case .suggestions(let suggestions) = catalog.lookup("water", direction: .toChinese) {
    assert(!suggestions.isEmpty)
} else { fatalError("Partial query must be suggestions, not a translation") }
for phrase in phrases {
    assert(catalog.lookup(phrase.chinese, direction: .toEnglish) == .phrase(phrase))
    assert(catalog.lookup(phrase.english, direction: .toChinese) == .phrase(phrase))
}
print("English bilingual lookup, direction, aliases, correction boundaries and all phrase roundtrips passed")
