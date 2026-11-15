import SwiftUI

struct EnglishView: View {
    private enum Mode: String, CaseIterable { case lookup = "中英查句", practice = "场景练习" }
    private let catalog = EnglishCatalog.bundled()
    @StateObject private var speech = SpeechInput(localeIdentifier: "zh-CN", onDeviceOnly: true)
    @StateObject private var audio = EnglishAudio()
    @State private var mode: Mode = .lookup
    @State private var direction: EnglishDirection = .toEnglish
    @State private var query = ""
    @State private var result: EnglishCatalog.Result?
    @State private var lastLookupQuery = ""
    @State private var lastLookupDirection: EnglishDirection = .toEnglish
    @State private var scene = "问候"
    @State private var turn = 0
    @State private var revealed = false
    @AppStorage("englishCompleted") private var completed = ""
    @Environment(\.scenePhase) private var scenePhase
    private var scenePhrases: [EnglishPhrase] { catalog.phrases.filter { $0.scene == scene } }
    private var current: EnglishPhrase? { scenePhrases.indices.contains(turn) ? scenePhrases[turn] : nil }
    private var busy: Bool { speech.isBusy || audio.isRecording || audio.preparing }

    var body: some View {
        ZStack {
            PaperBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    HStack {
                        Image(systemName: "bubble.left.and.bubble.right.fill").font(.system(size: 33)).foregroundStyle(Crayon.green)
                        VStack(alignment: .leading) {
                            Text("芽芽英语").font(.system(size: 30, weight: .heavy, design: .rounded))
                            Text("听一句 · 跟着说 · 听听自己").font(.subheadline)
                        }
                        Spacer(minLength: 0)
                    }
                    Text("离线句库 \(catalog.phrases.count) 句 · 不需要 AI 账号或 API Key")
                        .font(.callout).foregroundStyle(Crayon.green)
                    Picker("学习方式", selection: $mode) {
                        ForEach(Mode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }.pickerStyle(.segmented).disabled(busy)
                    if mode == .lookup { lookupCard; resultView; quickScenes }
                    else { practiceCard }
                    Text("本版按内置句库查找，不支持任意句子翻译。纠错只覆盖列出的常见例句；录音可自己回听，不评判发音对错。")
                        .font(.footnote).foregroundStyle(Crayon.ink.opacity(0.85))
                    if let error = audio.error { Text(error).font(.callout).foregroundStyle(.red) }
                }.padding(20).padding(.bottom, 18).frame(maxWidth: 780).frame(maxWidth: .infinity)
            }.scrollDismissesKeyboard(.interactively)
        }.foregroundStyle(Crayon.ink).tint(Crayon.green).preferredColorScheme(.light)
        .onChange(of: speech.transcript) { if !$0.isEmpty { query = $0; result = nil } }
        .onChange(of: direction) { value in speech.setLanguage(value.locale); if value != lastLookupDirection { result = nil } }
        .onChange(of: query) { value in if value != lastLookupQuery { result = nil } }
        .onChange(of: mode) { _ in speech.stop(); audio.clear() }
        .onChange(of: scene) { _ in turn = 0; revealed = false; audio.clear() }
        .onChange(of: scenePhase) { if $0 == .background { speech.stop(); audio.clear() } }
        .onDisappear { speech.stop(); audio.clear() }
    }
    private var lookupCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Picker("查找方向", selection: $direction) {
                ForEach(EnglishDirection.allCases) { Text($0.rawValue).tag($0) }
            }.pickerStyle(.segmented).disabled(busy)
            TextField(text: $query, axis: .vertical) {
                Text(direction == .toEnglish ? "例如：我想喝水" : "For example: I am hungry.").foregroundColor(Crayon.ink.opacity(0.6))
            }.font(.system(size: 22, design: .rounded)).foregroundColor(Crayon.ink)
                .lineLimit(2...4).padding(16).background(.white, in: RoundedRectangle(cornerRadius: 15))
                .disabled(busy).submitLabel(.search).onSubmit(lookup)
                .accessibilityIdentifier("englishQuery")
            HStack {
                Button { if !speech.isBusy { audio.clear() }; speech.toggle() } label: {
                    Label(speech.buttonTitle, systemImage: speech.isRecording ? "stop.circle.fill" : "mic.fill")
                }.buttonStyle(CrayonButtonStyle(color: Crayon.yellow)).disabled(audio.isRecording || audio.preparing)
                Spacer(minLength: 0)
                Button("查句", action: lookup).buttonStyle(CrayonButtonStyle(color: Crayon.green, ink: .white))
                    .disabled(busy || query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            if speech.isRecording { Text("正在录音 \(speech.elapsedText) · 说完再点“说好了”").monospacedDigit().font(.callout) }
            if speech.phase == .transcribing { HStack { ProgressView(); Text("正在离线听写…") } }
            if let error = speech.error { Text(error).font(.callout).foregroundStyle(.red) }
            Text("麦克风仅尝试设备上的离线听写；不可用时请手动输入或点下方句子。")
                .font(.caption).foregroundStyle(Crayon.ink.opacity(0.8))
        }.padding(18).crayonCard(Crayon.peach.opacity(0.6))
    }
    @ViewBuilder private var resultView: some View {
        if let result {
            switch result {
            case .phrase(let phrase):
                phraseCard(phrase, title: "句库匹配")
            case .correction(let correction):
                VStack(alignment: .leading, spacing: 12) {
                    Label("常见错误示例", systemImage: "pencil.tip.crop.circle").font(.headline)
                    Text("原句：\(correction.original)").foregroundStyle(Crayon.ink)
                    Text(correction.corrected).font(.system(size: 27, weight: .bold, design: .rounded)).textSelection(.enabled)
                    Text(correction.chinese).font(.title3)
                    Text(correction.explanation).font(.body)
                    Text("这是内置例句的修正，不是对所有英文的完整检查。").font(.caption)
                    playbackButtons(correction.corrected, chinese: correction.chinese)
                }.padding(18).crayonCard(Crayon.yellow)
            case .suggestions(let phrases):
                VStack(alignment: .leading, spacing: 13) {
                    Text("找到相关例句，请选一句").font(.headline)
                    Text("下面是句库里的例句，并非对输入内容的直接翻译。").font(.caption)
                    ForEach(phrases) { phrase in
                        Button { show(phrase) } label: {
                            VStack(alignment: .leading, spacing: 5) { Text(phrase.chinese); Text(phrase.english).font(.headline) }
                                .foregroundStyle(Crayon.ink).frame(maxWidth: .infinity, alignment: .leading).padding(14).crayonCard(.white)
                        }.buttonStyle(.plain).disabled(busy)
                    }
                }
            case .missing:
                VStack(alignment: .leading, spacing: 10) {
                    Text("这句话暂时不在离线句库里").font(.headline)
                    Text("可以试试“我想喝水”“我七岁了”，或从下方场景挑一句。没有匹配不代表英文正确或错误。")
                    Button("填入纠错示例") { direction = .toChinese; query = "Yesterday I go to the park." }
                        .buttonStyle(CrayonButtonStyle()).disabled(busy)
                }.padding(18).crayonCard(Crayon.blue)
            }
        }
    }
    private func phraseCard(_ phrase: EnglishPhrase, title: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.headline).foregroundStyle(Crayon.green)
            Text(phrase.english).font(.system(size: 28, weight: .bold, design: .rounded)).textSelection(.enabled)
            Text(phrase.chinese).font(.title3).textSelection(.enabled)
            playbackButtons(phrase.english, chinese: phrase.chinese)
        }.padding(18).crayonCard(Crayon.blue)
    }
    private func playbackButtons(_ english: String, chinese: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Button { audio.speak(english) } label: { Label("读英文", systemImage: "speaker.wave.2.fill") }
                    .buttonStyle(CrayonButtonStyle(color: Crayon.yellow)).disabled(busy)
                Button("慢慢读") { audio.speak(english, slow: true) }.buttonStyle(CrayonButtonStyle(color: .white)).disabled(busy)
            }
            Button("读中文意思") { audio.speak(chinese, language: "zh-CN") }.font(.callout).foregroundStyle(Crayon.green).disabled(busy)
        }
    }
    private var quickScenes: some View {
        VStack(alignment: .leading, spacing: 13) {
            Text("从熟悉的生活开始").font(.system(.title3, design: .rounded).weight(.bold))
            Picker("场景", selection: $scene) { ForEach(catalog.scenes, id: \.self) { Text($0).tag($0) } }.pickerStyle(.menu).disabled(busy)
            ForEach(scenePhrases) { phrase in
                Button { show(phrase) } label: {
                    HStack { VStack(alignment: .leading, spacing: 4) { Text(phrase.chinese); Text(phrase.english).font(.callout) }; Spacer(); Image(systemName: "speaker.wave.2") }
                        .foregroundStyle(Crayon.ink).padding(14).crayonCard(.white)
                }.buttonStyle(.plain).disabled(busy)
            }
        }
    }
    private var practiceCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Picker("练哪个场景", selection: $scene) { ForEach(catalog.scenes, id: \.self) { Text($0).tag($0) } }.pickerStyle(.menu).disabled(busy)
            if let current {
                Text("第 \(turn + 1) / \(scenePhrases.count) 句").font(.headline)
                Text("试着用英文说：").font(.callout)
                Text(current.chinese).font(.system(size: 27, weight: .bold, design: .rounded))
                if revealed {
                    Text(current.english).font(.system(size: 28, weight: .bold, design: .rounded)).textSelection(.enabled)
                    playbackButtons(current.english, chinese: current.chinese)
                } else {
                    Button("看看英文提示") { revealed = true }.buttonStyle(CrayonButtonStyle(color: Crayon.blue)).disabled(busy)
                }
                Text("先想一想 → 听示范 → 录一句 → 回听比较").font(.callout)
                Button { audio.toggleRecording() } label: {
                    Label(audio.isRecording ? "说好了，保存回听" : (audio.preparing ? "正在准备，取消" : "录下我的跟读"), systemImage: audio.isRecording ? "stop.circle.fill" : "mic.fill")
                }.buttonStyle(CrayonButtonStyle(color: Crayon.pink)).disabled(speech.isBusy)
                if audio.isRecording { Text("正在录音 \(Int(audio.seconds)) 秒").monospacedDigit() }
                if audio.hasRecording {
                    Button { audio.replay() } label: { Label(audio.isPlaying ? "停止回放" : "听听我刚才说的", systemImage: "play.circle.fill") }
                        .buttonStyle(CrayonButtonStyle(color: Crayon.blue))
                    Button("删除这段录音") { audio.clear() }.font(.callout).foregroundStyle(Crayon.green)
                }
                Button(turn + 1 == scenePhrases.count ? "我练好了，完成这个场景" : "我练好了，下一句") { advance() }
                    .buttonStyle(CrayonButtonStyle(color: Crayon.green, ink: .white)).disabled(busy)
                Text("由自己决定何时进入下一句；不自动打分。离开页面或切换句子会删除当前录音。").font(.caption)
            } else {
                Label("这个场景练完啦！", systemImage: "star.fill").font(.title2.bold())
                Text("想再练一遍，随时可以。")
                Button("再练一次") { turn = 0; revealed = false; audio.clear() }.buttonStyle(CrayonButtonStyle())
            }
            let count = Set(completed.split(separator: ",").map(String.init)).count
            Text("自己标记练过：\(count) 句").font(.caption)
        }.padding(18).crayonCard(Crayon.peach.opacity(0.65))
    }
    private func lookup() {
        guard !busy else { return }
        audio.clear()
        lastLookupQuery = query; lastLookupDirection = direction
        result = catalog.lookup(query, direction: direction)
        if case .phrase(let phrase)? = result { audio.speak(phrase.english) }
        if case .correction(let correction)? = result { audio.speak(correction.corrected) }
    }
    private func show(_ phrase: EnglishPhrase) {
        audio.clear()
        // Leave the query alone so its onChange does not erase this selection.
        result = .phrase(phrase)
        audio.speak(phrase.english)
    }
    private func advance() {
        guard let current else { return }
        var ids = Set(completed.split(separator: ",").map(String.init)); ids.insert(current.id)
        completed = ids.sorted().joined(separator: ",")
        audio.clear(); revealed = false; turn += 1
    }
}
