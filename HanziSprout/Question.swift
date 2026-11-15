import Foundation

struct Letter: Identifiable {
    let id: Int
    let text: String
    let pinyin: String
}

enum Question {
    static func letters(_ text: String) -> [Letter] {
        let source = Array(text)
        // Transform the whole phrase, so context can inform polyphonic readings.
        let reading = text.applyingTransform(.mandarinToLatin, reverse: false) ?? text
        let syllables = reading.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        let chinese = source.enumerated().filter { isHanzi($0.element) }
        // Mixed punctuation can break alignment; never show a different character's syllable.
        let aligned = source.allSatisfy(isHanzi) && syllables.count == source.count
        return chinese.map { index, character in
            let fallback = String(character).applyingTransform(.mandarinToLatin, reverse: false) ?? ""
            return Letter(id: index, text: String(character), pinyin: aligned ? syllables[index] : fallback)
        }
    }
    static func isHanzi(_ character: Character) -> Bool {
        character.unicodeScalars.contains { (0x3400...0x9FFF).contains($0.value) || (0x20000...0x323AF).contains($0.value) }
    }
    static func phrase(_ question: String) -> String {
        let patterns = ["[‘'“\"]([^’'”\"]+)[’'”\"]", "的([\\p{Han}])(?:字)?(?:怎么写|怎样写|如何写)", "([\\p{Han}]+?)(?:怎么写|怎样写|如何写)"]
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern),
                  let match = regex.matches(in: question, range: NSRange(question.startIndex..., in: question)).last,
                  let range = Range(match.range(at: 1), in: question) else { continue }
            return String(question[range])
        }
        return question
    }
}
