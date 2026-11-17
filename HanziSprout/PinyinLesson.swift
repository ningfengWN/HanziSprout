import Foundation

struct PinyinExercise: Identifiable {
    let id: String
    let pinyin: String
    let word: String
    let initial: String
    let hint: String
}

enum PinyinLesson {
    static let groups = ["b / d / p / q", "zh / ch / sh 与 z / c / s"]
    static let exercises: [PinyinExercise] = [
        .init(id: "ba", pinyin: "bā", word: "八", initial: "b", hint: "b：先闭双唇，轻轻放开，送气弱。"),
        .init(id: "da", pinyin: "dā", word: "搭", initial: "d", hint: "d：舌尖抵住上齿龈再放开，送气弱。"),
        .init(id: "pa", pinyin: "pā", word: "趴", initial: "p", hint: "p：闭唇后送出明显气流，可以用纸巾感受。"),
        .init(id: "qi", pinyin: "qī", word: "七", initial: "q", hint: "q：舌面前部靠近硬腭，送气明显；注意字形右上圆圈。"),
        .init(id: "zhi", pinyin: "zhī", word: "枝", initial: "zh", hint: "zh：舌尖翘起，送气弱。"),
        .init(id: "zi", pinyin: "zī", word: "姿", initial: "z", hint: "z：舌尖靠近上齿背，舌尖不翘起。"),
        .init(id: "chi", pinyin: "chī", word: "吃", initial: "ch", hint: "ch：舌尖翘起，送气明显。"),
        .init(id: "ci", pinyin: "cī", word: "疵", initial: "c", hint: "c：舌尖不翘起，送气明显。"),
        .init(id: "shi", pinyin: "shī", word: "诗", initial: "sh", hint: "sh：舌尖翘起，让气流从窄缝通过。"),
        .init(id: "si", pinyin: "sī", word: "丝", initial: "s", hint: "s：舌尖不翘起，让气流从齿间通过。")
    ]
    static func items(group: Int) -> [PinyinExercise] {
        exercises.filter { group == 0 ? ["b", "d", "p", "q"].contains($0.initial) : !["b", "d", "p", "q"].contains($0.initial) }
    }
    /// Match the entire recognized utterance, never a substring. Homophones are
    /// accepted because this exercise tests syllables rather than characters.
    static func transcription(_ text: String, matches exercise: PinyinExercise) -> Bool {
        let cleaned = text.filter { !$0.isWhitespace && !$0.isPunctuation }
        guard !cleaned.isEmpty else { return false }
        let latin = cleaned.applyingTransform(.mandarinToLatin, reverse: false) ?? cleaned
        return latin.lowercased().precomposedStringWithCanonicalMapping == exercise.pinyin
    }
}
