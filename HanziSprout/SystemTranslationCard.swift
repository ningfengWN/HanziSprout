import SwiftUI
import Translation

/// Apple's on-device Translation framework; no API key or developer server.
/// The system owns the language download/consent UI on supported devices.
@available(iOS 18.0, *)
struct SystemTranslationCard: View {
    let text: String
    let direction: EnglishDirection
    let audioBusy: Bool
    let speak: (String, String, Bool) -> Void
    @State private var configuration: TranslationSession.Configuration?
    @State private var translated: String?
    @State private var loading = false
    @State private var error: String?
    private var source: Locale.Language { Locale.Language(identifier: direction == .toEnglish ? "zh-Hans" : "en") }
    private var target: Locale.Language { Locale.Language(identifier: direction == .toEnglish ? "en" : "zh-Hans") }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("系统离线翻译", systemImage: "character.bubble.fill").font(.headline)
            Text("首次使用，系统可能询问是否下载中英文语言包。下载后可离线翻译；不需要 AI API Key。").font(.caption)
            Button(loading ? "正在准备或翻译…" : "用系统翻译这句话") {
                error = nil; translated = nil; loading = true
                if configuration == nil {
                    configuration = .init(source: source, target: target)
                } else { configuration?.invalidate() }
            }.buttonStyle(CrayonButtonStyle(color: Crayon.yellow))
                .disabled(loading || audioBusy || text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            if loading { ProgressView().tint(Crayon.green) }
            if let translated {
                Text(translated).font(.system(size: 27, weight: .bold, design: .rounded)).textSelection(.enabled)
                HStack {
                    Button("朗读译文") { speak(translated, direction == .toEnglish ? "en-US" : "zh-CN", false) }
                        .buttonStyle(CrayonButtonStyle(color: Crayon.blue)).disabled(audioBusy)
                    Button("慢慢读") { speak(translated, direction == .toEnglish ? "en-US" : "zh-CN", true) }
                        .buttonStyle(CrayonButtonStyle(color: .white)).disabled(audioBusy)
                }
                if direction == .toChinese {
                    Button("读原来的英文") { speak(text, "en-US", false) }.font(.callout).disabled(audioBusy)
                }
                Text("这是系统翻译结果，未进行语法或发音评分。").font(.caption)
            }
            if let error { Text(error).font(.callout).foregroundStyle(.red) }
        }.foregroundStyle(Crayon.ink).padding(18).crayonCard(Crayon.blue)
            .translationTask(configuration) { @MainActor session in
                do {
                    try await session.prepareTranslation()
                    let response = try await session.translate(text)
                    guard !Task.isCancelled else { return }
                    translated = response.targetText
                    loading = false
                } catch {
                    guard !Task.isCancelled else { return }
                    loading = false
                    self.error = "系统翻译未完成。请确认设备支持该语言、语言包已下载；也可以重试或使用内置句库。"
                }
            }
    }
}
