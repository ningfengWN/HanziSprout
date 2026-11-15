import SwiftUI

struct ContentView: View {
    @StateObject private var speech = SpeechInput()
    @State private var question = ""
    @State private var phrase = ""
    @State private var selected: Letter?
    @AppStorage("recentWords") private var recent = ""
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            ZStack {
                PaperBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 26) {
                        header
                        questionCard
                        if !phrase.isEmpty { results }
                        examples
                        if !recent.isEmpty { history }
                        Text("字芽 1.2 · 把今天的小故事写下来")
                            .font(.system(.footnote, design: .rounded)).foregroundStyle(Crayon.ink.opacity(0.75))
                            .frame(maxWidth: .infinity).padding(.top, 6)
                    }.padding(20).padding(.bottom, 16).frame(maxWidth: 780).frame(maxWidth: .infinity)
                }.scrollDismissesKeyboard(.interactively)
            }
            .toolbar(.hidden, for: .navigationBar)
            .fullScreenCover(item: $selected) { letter in WritingView(letter: letter) }
        }
        .foregroundStyle(Crayon.ink).tint(Crayon.green).preferredColorScheme(.light)
        .onChange(of: speech.transcript) { value in if !value.isEmpty { question = value } }
        .onChange(of: scenePhase) { value in if value == .background { speech.stop() } }
    }
    private var header: some View {
        HStack(alignment: .center, spacing: 13) {
            Image(systemName: "leaf.fill").font(.system(size: 35)).foregroundStyle(Crayon.green)
                .frame(width: 68, height: 68).crayonCard(Crayon.yellow).rotationEffect(.degrees(-6))
            VStack(alignment: .leading, spacing: 3) {
                Text("字芽").font(.system(size: 34, weight: .heavy, design: .rounded)).foregroundStyle(Crayon.green)
                Text("我的写字小帮手").font(.system(.subheadline, design: .rounded).weight(.semibold)).foregroundStyle(Crayon.ink)
            }
            Spacer(minLength: 0)
            Image(systemName: "sun.max.fill").font(.system(size: 30)).foregroundStyle(Color(red: 0.79, green: 0.46, blue: 0.16)).rotationEffect(.degrees(12)).accessibilityHidden(true)
        }.padding(.top, 10)
    }
    private var questionCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("不会写？我来教你！").font(.system(size: 25, weight: .heavy, design: .rounded)).foregroundStyle(Crayon.ink)
            Text("说一个词，或一句话，\n再点一下你想写的字。").font(.system(.body, design: .rounded)).foregroundStyle(Crayon.ink.opacity(0.9)).lineSpacing(4)
            TextField(text: $question, axis: .vertical) {
                Text("例如：蝴蝶的蝶怎么写？").foregroundColor(Crayon.ink.opacity(0.65))
            }
            .font(.system(size: 21, weight: .medium, design: .rounded)).foregroundColor(Crayon.ink)
            .tint(Crayon.green).lineLimit(2...4).padding(16)
            .background(Color.white.opacity(0.95), in: RoundedRectangle(cornerRadius: 15))
            .overlay(RoundedRectangle(cornerRadius: 15).stroke(Crayon.ink.opacity(0.5), style: StrokeStyle(lineWidth: 1.5, dash: [6, 3])))
            .disabled(speech.isBusy).submitLabel(.search).onSubmit(find)
            HStack(spacing: 10) {
                Button(action: speech.toggle) {
                    Label(speech.buttonTitle, systemImage: speech.isRecording ? "stop.circle.fill" : "mic.fill")
                        .frame(maxWidth: .infinity).fixedSize(horizontal: false, vertical: true)
                }.buttonStyle(CrayonButtonStyle(color: speech.isRecording ? Crayon.pink : Crayon.yellow))
                Button("找字", action: find).buttonStyle(CrayonButtonStyle(color: Crayon.green, ink: .white))
                    .disabled(speech.isBusy || question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            if speech.isRecording {
                Label("正在录音 \(speech.elapsedText) · 说完点“说好了”", systemImage: "waveform")
                    .font(.system(.callout, design: .rounded).weight(.semibold)).monospacedDigit().foregroundStyle(Crayon.green)
            }
            if speech.phase == .preparing { Text("允许麦克风权限后，看到计时再开始说话哦。").font(.callout).foregroundStyle(Crayon.ink) }
            if speech.phase == .transcribing { HStack { ProgressView().tint(Crayon.green); Text("正在听懂你的小故事…").font(.callout).foregroundStyle(Crayon.ink) } }
            if let error = speech.error { Text(error).font(.callout).foregroundStyle(Color(red: 0.64, green: 0.22, blue: 0.17)) }
        }.padding(20).crayonCard(Crayon.peach.opacity(0.6))
    }
    private var results: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("点一下，要写哪个字？", systemImage: "hand.point.up.left.fill").font(.system(.title3, design: .rounded).weight(.bold)).foregroundStyle(Crayon.ink)
            Text("先看看有没有听错；同音字可以用拼音键盘改一改。").font(.callout).foregroundStyle(Crayon.ink.opacity(0.85))
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 92))], spacing: 14) {
                ForEach(Question.letters(phrase)) { letter in
                    Button { open(letter) } label: {
                        VStack(spacing: 5) {
                            Text(letter.pinyin).font(.system(size: 23, weight: .semibold, design: .rounded)).foregroundStyle(Crayon.green)
                            Text(letter.text).font(.system(size: 46, weight: .medium, design: .serif)).foregroundStyle(Crayon.ink)
                        }.frame(maxWidth: .infinity).padding(.vertical, 13).crayonCard(Crayon.blue)
                    }.buttonStyle(.plain)
                }
            }
            if Question.letters(phrase).isEmpty { Text("还没有找到汉字，试试用拼音键盘输入词语。").foregroundStyle(Crayon.ink) }
        }
    }
    private var examples: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("试着说一说", systemImage: "bubble.left.and.bubble.right.fill").font(.system(.title3, design: .rounded).weight(.bold))
            ForEach(Array(["蝴蝶的蝶怎么写", "今天很开心", "我和妈妈去公园"].enumerated()), id: \.offset) { index, example in
                Button { question = example; find() } label: {
                    HStack(spacing: 12) {
                        Image(systemName: ["leaf.fill", "heart.fill", "sun.max.fill"][index]).foregroundStyle(Crayon.green)
                        Text(example).font(.system(.body, design: .rounded).weight(.semibold)).foregroundStyle(Crayon.ink)
                        Spacer(minLength: 2)
                        Image(systemName: "arrow.up.left").foregroundStyle(Crayon.ink)
                    }.padding(16).crayonCard([Crayon.yellow, Crayon.pink, Crayon.blue][index])
                }.buttonStyle(.plain).disabled(speech.isBusy)
            }
        }
    }
    private var history: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack {
                Label("我的小字本", systemImage: "book.closed.fill").font(.system(.title3, design: .rounded).weight(.bold))
                Spacer()
                Button("清空") { recent = "" }.font(.callout).foregroundStyle(Crayon.green)
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 65))], spacing: 12) {
                ForEach(Question.letters(recent)) { letter in
                    Button(letter.text) { open(letter) }.font(.system(size: 32, design: .serif)).foregroundStyle(Crayon.ink)
                        .frame(maxWidth: .infinity).padding(.vertical, 9).crayonCard(.white).disabled(speech.isBusy)
                }
            }
        }
    }
    private func find() {
        guard !speech.isBusy else { return }
        speech.stop()
        phrase = Question.phrase(question.trimmingCharacters(in: .whitespacesAndNewlines))
        let letters = Question.letters(phrase)
        if letters.count == 1, let letter = letters.first { open(letter) }
    }
    private func open(_ letter: Letter) {
        speech.stop()
        recent = String((letter.text + recent.filter { String($0) != letter.text }).prefix(24))
        selected = letter
    }
}
