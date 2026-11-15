import Foundation

struct EnglishPhrase: Codable, Identifiable, Equatable {
    let id: String
    let scene: String
    let chinese: String
    let english: String
    let chineseAliases: [String]
    let englishAliases: [String]
}
struct EnglishCorrection: Codable, Identifiable, Equatable {
    let id: String
    let original: String
    let corrected: String
    let chinese: String
    let explanation: String
}
enum EnglishDirection: String, CaseIterable, Identifiable {
    case toEnglish = "中文 → 英文"
    case toChinese = "英文 → 中文"
    var id: String { rawValue }
    var locale: String { self == .toEnglish ? "zh-CN" : "en-US" }
}
struct EnglishCatalog {
    enum Result: Equatable {
        case phrase(EnglishPhrase)
        case correction(EnglishCorrection)
        case suggestions([EnglishPhrase])
        case missing
    }
    let phrases: [EnglishPhrase]
    let corrections: [EnglishCorrection]
    var scenes: [String] {
        phrases.reduce(into: [String]()) { result, phrase in
            if !result.contains(phrase.scene) { result.append(phrase.scene) }
        }
    }
    static func bundled() -> EnglishCatalog {
        func read<T: Decodable>(_ name: String) -> [T] {
            guard let url = Bundle.main.url(forResource: name, withExtension: "json", subdirectory: "LearningAssets"),
                  let data = try? Data(contentsOf: url), let value = try? JSONDecoder().decode([T].self, from: data) else { return [] }
            return value
        }
        return EnglishCatalog(phrases: read("EnglishPhrases"), corrections: read("EnglishCorrections"))
    }
    static func normalized(_ text: String) -> String {
        // Ignore presentation punctuation/case, but preserve word boundaries and
        // spelling: do not turn "now here" into "nowhere" or guess corrections.
        let text = text.lowercased().replacingOccurrences(of: "’", with: "'")
            .replacingOccurrences(of: "‘", with: "'")
        let filtered = text.unicodeScalars.filter {
            CharacterSet.letters.contains($0) || CharacterSet.decimalDigits.contains($0)
                || CharacterSet.whitespacesAndNewlines.contains($0) || $0 == "'"
        }
        return String(String.UnicodeScalarView(filtered)).split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
    }
    func lookup(_ query: String, direction: EnglishDirection) -> Result {
        let key = Self.normalized(query)
        guard !key.isEmpty else { return .missing }
        if direction == .toChinese, let correction = corrections.first(where: { Self.normalized($0.original) == key }) {
            return .correction(correction)
        }
        func sources(_ phrase: EnglishPhrase) -> [String] {
            direction == .toEnglish ? [phrase.chinese] + phrase.chineseAliases : [phrase.english] + phrase.englishAliases
        }
        if let phrase = phrases.first(where: { sources($0).contains(where: { Self.normalized($0) == key }) }) { return .phrase(phrase) }
        guard key.count >= 2 else { return .missing }
        let matches = phrases.filter { sources($0).contains(where: { Self.normalized($0).contains(key) }) }
        return matches.isEmpty ? .missing : .suggestions(Array(matches.prefix(10)))
    }
}
