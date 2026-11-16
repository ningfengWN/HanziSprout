import SwiftUI

struct AIEnglishView: View {
    @AppStorage("zhipuEnabled") private var enabled = false
    @AppStorage("aiAutoRead") private var autoRead = true
    @AppStorage("aiAutoSend") private var autoSend = true
    @StateObject private var model = TutorModel()
    @StateObject private var speech = SpeechInput(localeIdentifier: "zh-CN", onDeviceOnly: true)
    @StateObject private var audio = EnglishAudio()
    @State private var input = ""
    @State private var language: EnglishDirection = .toEnglish
    @State private var conversation = false
    @State private var audience: TutorAudience = .child
    @State private var scene = "去公园"
    @State private var settings = false
    @State private var awaitingTranscription = false
    @Environment(\.scenePhase) private var scenePhase
    private var busy: Bool { speech.isBusy || model.loading }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Label("AI 英语伙伴", systemImage: "sparkles").font(.title3.bold())
                Spacer()
                Button("AI 设置") { settings = true }.foregroundStyle(Crayon.green).disabled(busy)
            }
            if !enabled {
                VStack(alignment: .leading, spacing: 12) {
                    Text("先保存你的智谱 API Key").font(.headline)
                    Text("使用模型标准 API Key，固定调用 GLM-4.7-Flash。不开启也能使用其他页面的离线功能。")
                    Button("打开 AI 设置") { settings = true }.buttonStyle(CrayonButtonStyle())
                }.padding(18).crayonCard(Crayon.yellow)
            }
            controls
            VStack(alignment: .leading, spacing: 13) {
                TextField(text: $input, axis: .vertical) {
                    Text(language == .toEnglish ? "例如：我想再玩五分钟" : "For example: Yesterday I go to the park.").foregroundColor(Crayon.ink.opacity(0.6))
                }.font(.system(size: 22, design: .rounded)).foregroundColor(Crayon.ink)
                    .lineLimit(2...5).padding(15).background(.white, in: RoundedRectangle(cornerRadius: 15))
                    .disabled(busy).submitLabel(.send).onSubmit(submit)
                Text("\(input.count) / 1,000").font(.caption).foregroundStyle(input.count > 1000 ? .red : Crayon.ink)
                HStack {
                    Button {
                        if !speech.isBusy { audio.clear() }
                        if speech.phase == .transcribing { awaitingTranscription = false }
                        speech.toggle()
                    } label: { Label(speech.buttonTitle, systemImage: speech.isRecording ? "stop.circle.fill" : "mic.fill") }
                        .buttonStyle(CrayonButtonStyle(color: Crayon.yellow)).disabled(!enabled || model.loading)
                    Spacer(minLength: 0)
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        let wait = max(0, Int(ceil(model.nextAllowedAt?.timeIntervalSince(context.date) ?? 0)))
                        Button(wait > 0 ? "等待 \(wait) 秒" : "发送", action: submit)
                            .buttonStyle(CrayonButtonStyle(color: Crayon.green, ink: .white))
                            .disabled(!enabled || busy || wait > 0 || input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || input.count > 1000)
                    }
                }
                if speech.isRecording { Text("正在录音 \(speech.elapsedText) · 说完再点“说好了”").font(.callout).monospacedDigit() }
                if speech.phase == .transcribing { HStack { ProgressView(); Text("正在离线听写…") } }
                if model.loading {
                    HStack { ProgressView(); Text("正在翻译、检查表达…"); Spacer(); Button("取消") { model.cancel() } }
                }
                if let error = speech.error { Text(error).font(.callout).foregroundStyle(.red) }
                if let error = model.error { Text(error).font(.callout).foregroundStyle(.red).textSelection(.enabled) }
            }.padding(18).crayonCard(Crayon.peach.opacity(0.6))
            ForEach(model.turns) { turn in answerCard(turn) }
            if !model.turns.isEmpty {
                Button("清空这次对话") { model.reset(); audio.clear(); input = "" }
                    .buttonStyle(CrayonButtonStyle(color: .white)).disabled(busy)
            }
            VStack(alignment: .leading, spacing: 8) {
                Toggle("说完并识别后自动发送", isOn: $autoSend).disabled(busy)
                Toggle("自动朗读英文回答", isOn: $autoRead)
                Text("发送内容：识别或输入的文字；对话模式另含本次最近 6 轮文字。录音不会上传到智谱。麦克风使用设备离线听写，不可用时可直接输入。")
                    .font(.caption).foregroundStyle(Crayon.ink.opacity(0.85))
                Text("AI 反馈仅供学习参考，可能有误；不根据转写文字评价发音。").font(.caption)
            }.foregroundStyle(Crayon.ink)
            if let error = audio.error { Text(error).font(.callout).foregroundStyle(.red) }
        }
        .sheet(isPresented: $settings) { AISettingsView() }
        .onChange(of: language) { value in resetSession(); speech.setLanguage(value.locale) }
        .onChange(of: conversation) { _ in resetSession() }
        .onChange(of: audience) { _ in resetSession() }
        .onChange(of: scene) { _ in resetSession() }
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
            guard autoRead, !speech.isBusy, let answer = model.turns.last?.answer else { return }
            let text = conversation ? answer.replyEnglish : answer.english
            if !text.isEmpty { audio.speak(text) }
        }
        .onChange(of: scenePhase) { if $0 == .background { stopSession() } }
        .onDisappear { stopSession(); model.reset() }
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
            Text("我说：\(turn.input)").font(.callout).textSelection(.enabled)
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
        audio.clear()
        let task: TutorTask = conversation ? .conversation : (language == .toEnglish ? .chineseToEnglish : .englishToChinese)
        model.send(input, task: task, audience: audience, scene: scene)
    }
    private func stopSession() {
        awaitingTranscription = false; speech.stop(); audio.clear(); model.cancel()
    }
    private func resetSession() { stopSession(); model.reset() }
}
