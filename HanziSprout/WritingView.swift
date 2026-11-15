import SwiftUI
import WebKit
import AVFoundation

struct WritingView: View {
    let letter: Letter
    @Environment(\.dismiss) private var dismiss
    @State private var pinyin = ""
    @State private var synthesizer = AVSpeechSynthesizer()
    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Button { dismiss() } label: { Label("换个字", systemImage: "chevron.left") }
                Spacer()
                Button {
                    let utterance = AVSpeechUtterance(string: letter.text)
                    utterance.voice = AVSpeechSynthesisVoice(language: "zh-CN")
                    utterance.rate = 0.35
                    synthesizer.speak(utterance)
                } label: { Label("听读音", systemImage: "speaker.wave.2") }
            }.padding(.horizontal).padding(.top, 8)
            TextField("拼音", text: $pinyin).font(.system(size: 36, weight: .medium, design: .rounded))
                .multilineTextAlignment(.center).textInputAutocapitalization(.never).autocorrectionDisabled()
                .accessibilityLabel("拼音，可点按修改多音字读音")
            Text("多音字可点拼音修改；单字朗读采用系统默认读音").font(.caption2).foregroundStyle(.secondary)
            StrokeWebView(character: letter.text)
        }
        .background(Color(red: 0.98, green: 0.97, blue: 0.94))
        .tint(Color(red: 0.14, green: 0.40, blue: 0.31))
        .onAppear { pinyin = letter.pinyin }
        .onDisappear { synthesizer.stopSpeaking(at: .immediate) }
    }
}

struct StrokeWebView: UIViewRepresentable {
    let character: String
    func makeCoordinator() -> Coordinator { Coordinator(character: character) }
    func makeUIView(context: Context) -> WKWebView {
        let view = WKWebView(frame: .zero)
        view.isOpaque = false
        view.backgroundColor = .clear
        view.scrollView.isScrollEnabled = false
        view.navigationDelegate = context.coordinator
        if let url = Bundle.main.url(forResource: "writer", withExtension: "html", subdirectory: "Resources") {
            view.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        }
        return view
    }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
    static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
        uiView.stopLoading(); uiView.navigationDelegate = nil
    }
    final class Coordinator: NSObject, WKNavigationDelegate {
        let character: String
        init(character: String) { self.character = character }
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            let encodedCharacter = String(data: try! JSONEncoder().encode(character), encoding: .utf8)!
            let url = Bundle.main.url(forResource: character, withExtension: "json", subdirectory: "Resources/Strokes")
            let data = url.flatMap { try? String(contentsOf: $0, encoding: .utf8) } ?? "null"
            webView.evaluateJavaScript("window.start(\(encodedCharacter), \(data));", completionHandler: nil)
        }
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            decisionHandler(navigationAction.request.url?.isFileURL == true ? .allow : .cancel)
        }
    }
}
