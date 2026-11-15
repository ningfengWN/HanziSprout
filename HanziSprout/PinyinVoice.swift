import Foundation

/// A Mandarin homophone sounds like the pinyin syllable, whereas reading its
/// Latin letters directly with TTS often spells letters or uses English sounds.
enum PinyinVoice {
    static let pronunciations: [String: String] = {
        guard let url = Bundle.main.url(forResource: "PinyinVoice", withExtension: "json", subdirectory: "LearningAssets"),
              let data = try? Data(contentsOf: url),
              let map = try? JSONDecoder().decode([String: String].self, from: data) else { return [:] }
        return map
    }()
    static func key(_ input: String) -> String {
        var text = input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            .replacingOccurrences(of: "u:", with: "ü").replacingOccurrences(of: "v", with: "ü")
            .precomposedStringWithCanonicalMapping
        guard let digit = text.last?.wholeNumberValue, (0...5).contains(digit) else { return text }
        text.removeLast()
        let marks: [Character: [Character]] = [
            "a": Array("āáǎà"), "e": Array("ēéěè"), "i": Array("īíǐì"),
            "o": Array("ōóǒò"), "u": Array("ūúǔù"), "ü": Array("ǖǘǚǜ")
        ]
        var letters = Array(text)
        for (base, tones) in marks {
            letters = letters.map { tones.contains($0) ? base : $0 }
        }
        guard (1...4).contains(digit) else { return String(letters) }
        let index = letters.firstIndex(of: "a") ?? letters.firstIndex(of: "e")
            ?? (String(letters).contains("ou") ? letters.firstIndex(of: "o") : nil)
            ?? letters.lastIndex(where: { marks[$0] != nil })
        if let index, let variants = marks[letters[index]] { letters[index] = variants[digit - 1] }
        return String(letters)
    }
    static func spokenText(for pinyin: String) -> String? { pronunciations[key(pinyin)] }
}
