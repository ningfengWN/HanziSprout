import SwiftUI
import WebKit
import AVFoundation

struct WritingView: View {
    let letter: Letter
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var pinyin = ""
    @State private var synthesizer = AVSpeechSynthesizer()
    @State private var speechError: String?
    @AppStorage("autoReadPinyin") private var autoRead = true
    var body: some View {
        ZStack {
            PaperBackground()
            VStack(spacing: 7) {
                HStack {
                    Button { dismiss() } label: { Label("换个字", systemImage: "chevron.left") }
                        .buttonStyle(CrayonButtonStyle(color: Crayon.yellow))
                    Spacer()
                    Toggle("自动读拼音", isOn: $autoRead)
                        .font(.system(.caption, design: .rounded).weight(.semibold)).foregroundStyle(Crayon.ink)
                        .toggleStyle(.switch).tint(Crayon.green).fixedSize()
                }.padding(.horizontal, 18).padding(.top, 7)
                VStack(spacing: 0) {
                    Text("拼 音 · 点喇叭跟着读").font(.system(.caption, design: .rounded).weight(.bold)).foregroundStyle(Crayon.ink)
                    HStack(spacing: 12) {
                        TextField(text: $pinyin) { Text("拼音").foregroundColor(Crayon.ink.opacity(0.65)) }
                            .font(.system(size: sizeClass == .regular ? 80 : 60, weight: .bold, design: .rounded))
                            .foregroundColor(Crayon.green).tint(Crayon.green).multilineTextAlignment(.center)
                            .textInputAutocapitalization(.never).autocorrectionDisabled()
                            .submitLabel(.done).onSubmit(readPinyin)
                            .accessibilityLabel("大号拼音，可修改多音字读音")
                        Button(action: readPinyin) {
                            Image(systemName: "speaker.wave.2.fill").font(.system(size: 25)).padding(3)
                        }.buttonStyle(CrayonButtonStyle(color: Crayon.yellow)).accessibilityLabel("读拼音")
                    }
                    Text("多音字可点拼音修改，例如 háng 或 hang2")
                        .font(.caption2).foregroundStyle(Crayon.ink.opacity(0.85))
                }.padding(.horizontal, 16).padding(.vertical, 8).crayonCard(Crayon.blue).padding(.horizontal, 18)
                if let speechError { Text(speechError).font(.caption).foregroundStyle(Color(red: 0.64, green: 0.22, blue: 0.17)).padding(.horizontal) }
                StrokeWebView(character: letter.text)
            }
        }
        .foregroundStyle(Crayon.ink).tint(Crayon.green).preferredColorScheme(.light)
        .onAppear { pinyin = letter.pinyin; if autoRead { readPinyin() } }
        .onDisappear {
            synthesizer.stopSpeaking(at: .immediate)
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }
    private func readPinyin() {
        speechError = nil
        guard let sound = PinyinVoice.spokenText(for: pinyin) else {
            speechError = "这个拼音暂时不能朗读，请检查拼写和声调。"; return
        }
        guard let voice = AVSpeechSynthesisVoice(language: "zh-CN") else {
            speechError = "设备暂时没有可用的普通话语音。"; return
        }
        do {
            let audio = AVAudioSession.sharedInstance()
            try audio.setCategory(.playback, mode: .spokenAudio, options: .mixWithOthers)
            try audio.setActive(true)
            synthesizer.stopSpeaking(at: .immediate)
            let utterance = AVSpeechUtterance(string: sound)
            utterance.voice = voice
            utterance.rate = 0.35
            utterance.volume = 1
            synthesizer.speak(utterance)
        } catch { speechError = "暂时不能播放声音，请检查设备音频输出后再试。" }
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
        if let url = Bundle.main.url(forResource: "writer", withExtension: "html", subdirectory: "LearningAssets") {
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
            let url = Bundle.main.url(forResource: character, withExtension: "json", subdirectory: "LearningAssets/Strokes")
            let data = url.flatMap { try? String(contentsOf: $0, encoding: .utf8) } ?? "null"
            webView.evaluateJavaScript("window.start(\(encodedCharacter), \(data));", completionHandler: nil)
        }
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            decisionHandler(navigationAction.request.url?.isFileURL == true ? .allow : .cancel)
        }
    }
}
