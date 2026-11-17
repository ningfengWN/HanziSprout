import SwiftUI
import AVFoundation

struct PinyinPracticeView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var speech = SpeechInput()
    @State private var speaker = AVSpeechSynthesizer()
    @State private var group = 0
    @State private var mode = 1
    @State private var index = 0
    @State private var reviewOnly = false
    @State private var feedback: String?
    @State private var answered = false
    @State private var correctAnswer = false
    @State private var awaitingSpeech = false
    @State private var autoAdvance: Task<Void, Never>?
    @AppStorage("pinyin.mistakes.v1") private var mistakes = ""
    @AppStorage("pinyin.completed.v1") private var completed = 0

    private var wrongIDs: Set<String> { Set(mistakes.split(separator: ",").map(String.init)) }
    private var pool: [PinyinExercise] {
        PinyinLesson.items(group: group).filter { !reviewOnly || wrongIDs.contains($0.id) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PaperBackground()
                ScrollView {
                    VStack(spacing: 20) {
                        Text("每天一点，读得更清楚").font(.headline)
                        NavigationLink("词语跟读与录音回放") { PinyinWordPracticeView() }
                            .buttonStyle(CrayonButtonStyle(color: Crayon.blue))
                        Picker("专项", selection: $group) {
                            ForEach(0..<PinyinLesson.groups.count, id: \.self) { Text(PinyinLesson.groups[$0]).tag($0) }
                        }.pickerStyle(.menu)
                        Picker("练习方式", selection: $mode) {
                            Text("听音选").tag(1)
                            Text("我来读").tag(2)
                        }.pickerStyle(.segmented)
                        Toggle("只练错题（\(wrongIDs.count)）", isOn: $reviewOnly)
                        Text("本组 \(pool.count) 个带调音节 · 已完成 \(completed) 次练习").font(.subheadline)
                        if !pool.isEmpty {
                            lesson(pool[index % pool.count])
                        } else {
                            Text("这一组还没有错题，关闭“只练错题”开始吧！").padding().crayonCard(Crayon.blue)
                        }
                        Text("拆分示范使用系统合成语音和声母呼读音，非真人本音录音。整体认读直接读整音节；三拼音节依次读声母、介音、韵母后合读。朗读核对使用系统中文语音识别，可能需要网络并由 Apple 处理录音。它只能辅助核对音节，不能专业评测口型或发音；孤立声母容易误识别，所以朗读练习使用完整音节。结果不确定时请家长复核。")
                            .font(.footnote).fixedSize(horizontal: false, vertical: true)
                    }.padding().frame(maxWidth: 700).frame(maxWidth: .infinity)
                }
            }.foregroundStyle(Crayon.ink).navigationTitle("芽芽练拼音")
        }
        .onChange(of: group) { _ in reset() }
        .onChange(of: mode) { _ in reset() }
        .onChange(of: reviewOnly) { _ in reset() }
        .onChange(of: speech.phase) { phase in
            guard phase == .idle, awaitingSpeech else { return }
            awaitingSpeech = false
            guard speech.error == nil, !pool.isEmpty, !speech.transcript.isEmpty else { return }
            let exercise = pool[index % pool.count]
            let match = PinyinLesson.transcription(speech.transcript, matches: exercise)
            record(match, exercise: exercise, message: match
                ? "听到“\(speech.transcript)”，音节匹配！"
                : "听到“\(speech.transcript)”，与 \(exercise.pinyin) 未匹配。听一次示范，再试试；也可能是识别偏差。")
        }
        .onChange(of: scenePhase) { phase in if phase == .background { cancelAudio() } }
        .onDisappear { cancelAudio() }
    }

    @ViewBuilder private func lesson(_ item: PinyinExercise) -> some View {
        VStack(spacing: 18) {
            Text(mode == 1 ? "先听示范，再选择拼音" : "看拼音，读完整音节")
            if mode != 1 || answered {
                Text(item.pinyin)
                    .font(.system(size: 76, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.6).accessibilityLabel(item.pinyin)
            } else {
                Image(systemName: "ear.badge.waveform").font(.system(size: 64)).accessibilityLabel("听音选拼音")
            }
            if mode == 2 || answered {
                Text(PinyinLesson.spellingLabel(for: item)).font(.headline)
            }
            if mode != 0 {
                Button { play(item) } label: { Label("听示范", systemImage: "speaker.wave.2.fill") }
                    .buttonStyle(CrayonButtonStyle(color: Crayon.blue)).disabled(speech.isBusy)
            }
            if mode == 2 {
                Text(PinyinLesson.explanation(for: item)).font(.headline)
                Text("例如“\(item.word)”的读音。录音时只读一次音节。").font(.subheadline)
                Button {
                    speaker.stopSpeaking(at: .immediate)
                    if speech.phase == .recording { awaitingSpeech = true }
                    else if speech.phase != .idle { awaitingSpeech = false }
                    else { autoAdvance?.cancel(); autoAdvance = nil; feedback = nil; answered = false; correctAnswer = false }
                    speech.toggle()
                } label: {
                    Label(speech.buttonTitle, systemImage: speech.isRecording ? "stop.circle.fill" : "mic.fill")
                }.buttonStyle(CrayonButtonStyle(color: Crayon.peach))
                if speech.isRecording { Text("正在录音 \(speech.elapsedText)").accessibilityAddTraits(.updatesFrequently) }
                if let error = speech.error { Text(error).font(.subheadline) }
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 110))], spacing: 14) {
                    ForEach(PinyinLesson.choices(for: item, group: group)) { option in
                        Button(option.pinyin) {
                            let match = option.id == item.id
                            record(match, exercise: item, message: match ? "选对啦！" : "再看一看：正确的是 \(item.pinyin)。")
                        }.buttonStyle(CrayonButtonStyle()).disabled(answered)
                    }
                }
            }
            if let feedback {
                Text(feedback).font(.headline).accessibilityAddTraits(.isStaticText)
                Text(item.hint).font(.body)
                Text(PinyinLesson.explanation(for: item)).font(.headline)
                Button("下一题") { nextQuestion(item) }
                    .buttonStyle(CrayonButtonStyle(color: Crayon.blue))
            }
        }.padding(22).frame(maxWidth: .infinity).crayonCard(.white)
    }
    private func record(_ correct: Bool, exercise: PinyinExercise, message: String) {
        guard !answered else { return }
        answered = true; correctAnswer = correct; completed += 1; feedback = message
        if correct {
            autoAdvance?.cancel()
            autoAdvance = Task { @MainActor in
                do { try await Task.sleep(nanoseconds: 800_000_000) } catch { return }
                guard !Task.isCancelled, answered, correctAnswer else { return }
                nextQuestion(exercise)
            }
        }
        if !correct { var ids = wrongIDs; ids.insert(exercise.id); mistakes = ids.sorted().joined(separator: ",") }
    }
    private func nextQuestion(_ item: PinyinExercise) {
        cancelAudio()
        if answered && correctAnswer {
            var ids = wrongIDs; ids.remove(item.id); mistakes = ids.sorted().joined(separator: ",")
        }
        if !reviewOnly || !correctAnswer { index += 1 }
        feedback = nil; answered = false; correctAnswer = false
    }
    private func play(_ item: PinyinExercise) {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .spokenAudio)
            try session.setActive(true)
            speaker.stopSpeaking(at: .immediate)
            for text in PinyinLesson.demonstration(for: item) {
                let utterance = AVSpeechUtterance(string: text)
                utterance.voice = AVSpeechSynthesisVoice(language: "zh-CN")
                utterance.rate = 0.38
                utterance.postUtteranceDelay = 0.45
                speaker.speak(utterance)
            }
        } catch { answered = false; correctAnswer = false; feedback = "示范声音暂时不可用，请重试。" }
    }
    private func cancelAudio() { autoAdvance?.cancel(); autoAdvance = nil; awaitingSpeech = false; speech.stop(); speaker.stopSpeaking(at: .immediate) }
    private func reset() { cancelAudio(); index = 0; feedback = nil; answered = false; correctAnswer = false }
}
