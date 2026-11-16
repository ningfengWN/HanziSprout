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
    static let billing = URL(string: "https://platform.openai.com/settings/organization/billing/overview")!
    static let usage = URL(string: "https://platform.openai.com/usage")!
    static let subscription = URL(string: "https://chatgpt.com/settings/billing")!
    static let keys = URL(string: "https://platform.openai.com/api-keys")!
    static let creditsGuide = URL(string: "https://developers.openai.com/api/docs/guides/chatgpt-api-credits")!
    static let supportedRegions = URL(string: "https://developers.openai.com/api/docs/supported-countries")!
}
