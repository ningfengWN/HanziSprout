import SwiftUI

struct AIEnglishView: View {
    @AppStorage("zhipuEnabled") private var zhipuEnabled = false
    @AppStorage("openAIEnabled") private var openAIEnabled = false
    @AppStorage("aiProvider") private var providerRaw = AIProvider.zhipu.rawValue
    @AppStorage("aiAutoRead") private var autoRead = true
    @AppStorage("aiAutoSend") private var autoSend = true
    @StateObject private var model = TutorModel()
    @StateObject private var speech = SpeechInput(localeIdentifier: "zh-CN", onDeviceOnly: true)
    @StateObject private var audio = EnglishAudio()
    @State private var input = ""
    @State private var language: EnglishDirection = .toEnglish
    @State private var conversation = true
    @State private var options = false
    @State private var pendingInput = ""
    @FocusState private var inputFocused: Bool
    @State private var audience: TutorAudience = .child
    @State private var scene = "去公园"
    @State private var settings = false
    @State private var awaitingTranscription = false
    @Environment(\.scenePhase) private var scenePhase
    private var provider: AIProvider { AIProvider(rawValue: providerRaw) ?? .zhipu }
    private var enabled: Bool { provider == .openai ? openAIEnabled : zhipuEnabled }
    private var busy: Bool { speech.isBusy || model.loading }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("芽芽 · 英语伙伴").font(.headline)
                    Text("\(provider.title) · \(conversation ? scene : "翻译与纠错")").font(.caption).foregroundStyle(Crayon.green)
                }
                Spacer()
                Button { inputFocused = false; options = true } label: { Image(systemName: "slider.horizontal.3").padding(10) }.accessibilityLabel("对话选项")
                Menu {
                    Button("AI 接入设置") { inputFocused = false; settings = true }
                    Button("新对话", role: .destructive) { resetSession(); input = "" }
                } label: { Image(systemName: "ellipsis.circle").padding(10) }.accessibilityLabel("更多")
            }.padding(.horizontal, 18).padding(.vertical, 10)
            Divider()
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 22) {
                        if model.turns.isEmpty && pendingInput.isEmpty { welcome }
                        ForEach(model.turns) { turn in
                            userBubble(turn.input)
                            answerCard(turn)
                        }
                        if !pendingInput.isEmpty { userBubble(pendingInput) }
                        if model.loading {
                            HStack(spacing: 10) { ProgressView(); Text("伙伴正在想怎么说…").font(.callout); Button("停止") { model.cancel(); input = pendingInput; pendingInput = "" } }
                        }
                        if let error = model.error {
                            VStack(alignment: .leading, spacing: 10) {
                                Label(model.quotaReached ? "额度不足或已达到用量限制" : "这次没有发送成功", systemImage: "exclamationmark.triangle.fill").font(.headline)
                                Text(error).font(.callout).textSelection(.enabled)
                                if model.quotaReached {
                                    Text("这句话已保留。当前服务已暂停发送；处理账户额度或限制后，点下方按钮再试。也可以到 AI 设置手动切换服务商。").font(.callout)
                                    Button("已处理，恢复发送") { model.resumeAfterQuota(); input = pendingInput; pendingInput = "" }
                                } else {
                                    Button("放回输入框") { input = pendingInput; pendingInput = "" }
                                }
                            }.padding(16).crayonCard(Crayon.peach)
                        }
                        Color.clear.frame(height: 1).id("latest")
                    }.padding(18).frame(maxWidth: 780).frame(maxWidth: .infinity)
                }.scrollDismissesKeyboard(.interactively)
                    .onTapGesture { inputFocused = false }
                    .onChange(of: model.turns.last?.id) { _ in withAnimation { proxy.scrollTo("latest", anchor: .bottom) } }
                    .onChange(of: model.loading) { _ in withAnimation { proxy.scrollTo("latest", anchor: .bottom) } }
                    .onChange(of: inputFocused) { value in if value { withAnimation { proxy.scrollTo("latest", anchor: .bottom) } } }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { composer }
        .sheet(isPresented: $options) {
            NavigationStack {
                Form {
                    Section("练习方式") { controls }
                    Section("语音") {
                        Toggle("说完并识别后自动发送", isOn: $autoSend)
                        Toggle("自动朗读英文回答", isOn: $autoRead)
                    }
                    Section {
                        Text("识别或输入的文字发送到选中的服务商。对话附带最近 6 轮文字，录音不上传给模型。AI 可能误译或误判，文字纠错不等于发音评测。")
                    }.font(.caption)
                }.navigationTitle("对话选项").toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { options = false } } }
            }.preferredColorScheme(.light)
        }
        .sheet(isPresented: $settings) { AISettingsView() }
        .onChange(of: language) { value in resetSession(); speech.setLanguage(value.locale) }
        .onChange(of: conversation) { _ in resetSession() }
        .onChange(of: audience) { _ in resetSession() }
        .onChange(of: scene) { _ in resetSession() }
        .onChange(of: providerRaw) { _ in pendingInput = ""; stopSession(); model.reset(clearCooldown: true) }
        .onChange(of: enabled) { value in if !value { resetSession() } }
        .onChange(of: speech.transcript) { if !$0.isEmpty { input = $0 } }
        .onChange(of: speech.phase) { phase in
            if phase == .transcribing { awaitingTranscription = true }
            else if phase == .idle && awaitingTranscription {
                awaitingTranscription = false
                if autoSend && speech.error == nil && !speech.transcript.isEmpty {
                    input = speech.transcript; submit()
                }
            }
        }
        .onChange(of: model.turns.last?.id) { _ in
            pendingInput = ""
            guard autoRead, !speech.isBusy, let answer = model.turns.last?.answer else { return }
            let text = conversation ? answer.replyEnglish : answer.english
            if !text.isEmpty { audio.speak(text) }
        }
        .onChange(of: scenePhase) { if $0 == .background { stopSession() } }
        .onDisappear { stopSession(); model.reset() }
    }
    private var welcome: some View {
        VStack(alignment: .leading, spacing: 18) {
            Image(systemName: "bubble.left.and.bubble.right.fill").font(.system(size: 42)).foregroundStyle(Crayon.green)
            Text("今天想聊什么？").font(.system(size: 28, weight: .bold, design: .rounded))
            Text("用中文问怎么说，或用英文聊一聊。\n我会陪你接着说，也会帮你修改表达。").font(.body)
            if !enabled {
                Button("设置 \(provider.title) 并开始") { settings = true }.buttonStyle(CrayonButtonStyle())
            } else {
                ForEach(["我想去公园玩", "Hello! How are you?", "Yesterday I go to school."], id: \.self) { example in
                    Button { input = example; inputFocused = true } label: {
                        HStack { Text(example); Spacer(); Image(systemName: "arrow.up.left") }.padding(14).crayonCard(.white)
                    }.buttonStyle(.plain)
                }
            }
            Text("只保留本次会话最近 6 轮，不会自动切换服务商。").font(.caption).foregroundStyle(.secondary)
        }.padding(.vertical, 25)
    }
    private func userBubble(_ text: String) -> some View {
        HStack {
            Spacer(minLength: 36)
            Text(text).font(.system(size: 20, design: .rounded)).textSelection(.enabled)
                .padding(15).background(Crayon.green, in: RoundedRectangle(cornerRadius: 20)).foregroundStyle(.white)
        }
    }
    private var composer: some View {
        VStack(alignment: .leading, spacing: 9) {
            if inputFocused {
                HStack { Spacer(); Button { inputFocused = false } label: { Label("收起键盘", systemImage: "keyboard.chevron.compact.down") }.font(.callout) }
            }
            if speech.isRecording { Text("正在录音 \(speech.elapsedText) · 说完点停止").font(.callout).monospacedDigit() }
            if speech.phase == .transcribing { HStack { ProgressView(); Text("正在离线听写…").font(.callout) } }
            if let error = speech.error { Text(error).font(.caption).foregroundStyle(.red) }
            if let error = audio.error { Text(error).font(.caption).foregroundStyle(.red) }
            HStack(alignment: .bottom, spacing: 10) {
                Button {
                    inputFocused = false
                    if !speech.isBusy { audio.clear() }
                    if speech.phase == .transcribing { awaitingTranscription = false }
                    speech.toggle()
                } label: { Image(systemName: speech.isBusy ? "stop.circle.fill" : "mic.fill").font(.title2).frame(width: 44, height: 46) }
                    .disabled(!enabled || model.loading || model.quotaReached).accessibilityLabel(speech.buttonTitle)
                TextField("说点什么，或输入一句话…", text: $input, axis: .vertical)
                    .font(.system(size: 19, design: .rounded)).lineLimit(1...4).padding(12)
                    .background(.white, in: RoundedRectangle(cornerRadius: 18)).focused($inputFocused)
                    .disabled(busy).submitLabel(.send).onSubmit(submit)
                    .accessibilityIdentifier("aiChatInput")
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let wait = max(0, Int(ceil(model.nextAllowedAt?.timeIntervalSince(context.date) ?? 0)))
                    Button(action: submit) {
                        if wait > 0 { Text("\(wait)").font(.callout.bold()).frame(width: 44, height: 46) }
                        else { Image(systemName: "arrow.up.circle.fill").font(.system(size: 36)).frame(width: 44, height: 46) }
                    }.disabled(!enabled || busy || model.quotaReached || wait > 0 || input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || input.count > 1000)
                        .accessibilityLabel("发送")
                }
            }
            if input.count > 900 { Text("\(input.count) / 1,000").font(.caption).foregroundStyle(input.count > 1000 ? .red : Crayon.ink) }
        }.padding(.horizontal, 14).padding(.vertical, 10).background(Crayon.paper).overlay(alignment: .top) { Divider() }
    }
    private var controls: some View {
        VStack(spacing: 12) {
            Picker("用途", selection: $conversation) {
                Text("翻译与纠错").tag(false); Text("自由陪练").tag(true)
            }.pickerStyle(.segmented).disabled(busy)
            Picker("我说的语言", selection: $language) {
                Text("我说中文").tag(EnglishDirection.toEnglish)
                Text("我说英文").tag(EnglishDirection.toChinese)
            }.pickerStyle(.segmented).disabled(busy)
            HStack {
                Picker("适合谁", selection: $audience) { ForEach(TutorAudience.allCases) { Text($0.rawValue).tag($0) } }.pickerStyle(.menu)
                if conversation {
                    Picker("聊什么", selection: $scene) {
                        ForEach(["去公园", "在家", "吃东西", "学校", "买东西", "自由话题"], id: \.self) { Text($0).tag($0) }
                    }.pickerStyle(.menu)
                }
            }.disabled(busy)
        }
    }
    private func answerCard(_ turn: TutorTurn) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            if conversation {
                Label("伙伴回答", systemImage: "bubble.left.fill").font(.headline).foregroundStyle(Crayon.green)
                Text(turn.answer.replyEnglish).font(.system(size: 27, weight: .bold, design: .rounded)).textSelection(.enabled)
                Text(turn.answer.replyChinese).font(.title3).textSelection(.enabled)
                voiceButtons(turn.answer.replyEnglish, chinese: turn.answer.replyChinese)
                Divider()
                Text("这句话可以这样说").font(.headline)
            } else { Text(statusTitle(turn.answer.status)).font(.headline).foregroundStyle(Crayon.green) }
            if !turn.answer.english.isEmpty {
                Text(turn.answer.english).font(.system(size: 26, weight: .bold, design: .rounded)).textSelection(.enabled)
            }
            Text(turn.answer.chinese).font(.title3).textSelection(.enabled)
            if !turn.answer.corrections.isEmpty {
                Text("修改与原因").font(.headline)
                ForEach(Array(turn.answer.corrections.enumerated()), id: \.offset) { _, correction in
                    VStack(alignment: .leading, spacing: 5) {
                        Text("\(correction.before) → \(correction.after)").font(.headline).textSelection(.enabled)
                        Text(correction.reason).font(.callout)
                    }
                }
            }
            if !turn.answer.alternative.isEmpty {
                Text("还可以这样说：\(turn.answer.alternative)").font(.body).textSelection(.enabled)
                Button("读这个说法") { audio.speak(turn.answer.alternative) }.font(.callout).disabled(busy)
            }
            if !turn.answer.tip.isEmpty { Text(turn.answer.tip).font(.callout) }
            voiceButtons(turn.answer.english, chinese: turn.answer.chinese)
        }.padding(18).crayonCard(conversation ? Crayon.blue : Crayon.yellow.opacity(0.7))
    }
    private func voiceButtons(_ english: String, chinese: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if !english.isEmpty {
                HStack {
                    Button { audio.speak(english) } label: { Label("读英文", systemImage: "speaker.wave.2.fill") }
                        .buttonStyle(CrayonButtonStyle(color: .white)).disabled(busy)
                    Button("慢慢读") { audio.speak(english, slow: true) }.buttonStyle(CrayonButtonStyle(color: Crayon.pink)).disabled(busy)
                }
            }
            Button("读中文意思") { audio.speak(chinese, language: "zh-CN") }.font(.callout).foregroundStyle(Crayon.green).disabled(busy)
        }
    }
    private func statusTitle(_ status: TutorReply.Status) -> String {
        switch status {
        case .translation: return "自然英文表达"
        case .correct: return "AI 判断：没有发现明确错误"
        case .needs_correction: return "AI 建议这样修改"
        case .unclear: return "这句话还需要确认"
        }
    }
    private func submit() {
        guard enabled, !busy, model.canSend else { return }
        inputFocused = false
        pendingInput = input.trimmingCharacters(in: .whitespacesAndNewlines)
        audio.clear()
        let task: TutorTask = conversation ? .conversation : (language == .toEnglish ? .chineseToEnglish : .englishToChinese)
        model.send(pendingInput, provider: provider, task: task, audience: audience, scene: scene)
        input = ""
    }
    private func stopSession() {
        awaitingTranscription = false; speech.stop(); audio.clear(); model.cancel()
    }
    private func resetSession() { inputFocused = false; pendingInput = ""; stopSession(); model.reset() }
}
