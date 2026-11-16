import Foundation

enum AIProvider: String, CaseIterable, Identifiable {
    case zhipu, openai
    var id: String { rawValue }
    var title: String { self == .openai ? "OpenAI" : "智谱" }
    var modelName: String { self == .openai ? "gpt-6-luna" : "glm-4.7-flash" }
    // Keep the original service name: existing Zhipu keys need no migration.
    var keychainService: String { "com.ningfeng.HanziSprout." + rawValue }
}
enum OpenAIAccountLinks {
    static let keys = URL(string: "https://platform.openai.com/api-keys")!
    static let supportedRegions = URL(string: "https://developers.openai.com/api/docs/supported-countries")!
}
