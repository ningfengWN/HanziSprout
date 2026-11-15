import SwiftUI

struct ContentView: View {
    @StateObject private var speech = SpeechInput()
    @State private var question = ""
    @State private var phrase = ""
    @State private var selected: Letter?
    @AppStorage("recentWords") private var recent = ""
    @Environment(\.scenePhase) private var scenePhase
    private let green = Color(red: 0.14, green: 0.40, blue: 0.31)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HStack { Image(systemName: "leaf.fill"); Text("字芽").font(.largeTitle.bold()); Spacer(); Text("写下今天的小故事").font(.subheadline) }.foregroundStyle(green)
                    VStack(alignment: .leading, spacing: 10) {
                        Text("哪个字，想让我写给你看？").font(.title2.bold())
                        Text("可以说：“蝴蝶的蝶怎么写？”").foregroundStyle(.secondary)
                        TextField("说一句话，或输入一个词", text: $question, axis: .vertical)
                            .font(.title3).lineLimit(2...4).padding().background(.white, in: RoundedRectangle(cornerRadius: 18))
                            .submitLabel(.search).onSubmit(find)
                        HStack(spacing: 12) {
                            Button(action: speech.toggle) {
                                Label(speech.isRecording ? "说好了，停止" : "按一下，说给我听", systemImage: speech.isRecording ? "stop.circle.fill" : "mic.fill")
                            }.buttonStyle(.bordered).tint(speech.isRecording ? .red : green)
                            Spacer()
                            Button("找字", action: find).buttonStyle(.borderedProminent).tint(green).disabled(question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                        if speech.isRecording { Text("正在听…说完后点“停止”，再点“找字”。").foregroundStyle(green) }
                        if let error = speech.error { Text(error).font(.callout).foregroundStyle(.red) }
                    }
                    if !phrase.isEmpty {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("点一下你想写的字").font(.headline)
                            Text("识别结果可能有同音字，请先检查文字；读音也可以在大字页修改。备用：使用键盘的拼音输入选择正确的字。").font(.caption).foregroundStyle(.secondary)
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 88))], spacing: 14) {
                                ForEach(Question.letters(phrase)) { letter in
                                    Button { open(letter) } label: {
                                        VStack(spacing: 5) { Text(letter.pinyin).font(.callout); Text(letter.text).font(.system(size: 44, weight: .medium, design: .serif)) }
                                            .frame(maxWidth: .infinity).padding(.vertical, 14).background(.white, in: RoundedRectangle(cornerRadius: 18))
                                    }.foregroundStyle(green)
                                }
                            }
                            if Question.letters(phrase).isEmpty { Text("还没有找到汉字，请用拼音键盘输入词语，再试一次。") }
                        }
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        Text("试着问问").font(.headline)
                        ForEach(["蝴蝶的蝶怎么写", "今天很开心", "我和妈妈去公园"], id: \.self) { example in
                            Button { question = example; find() } label: { HStack { Text(example); Spacer(); Image(systemName: "arrow.up.left") }.padding().background(.white.opacity(0.8), in: RoundedRectangle(cornerRadius: 14)) }.foregroundStyle(green)
                        }
                    }
                    if !recent.isEmpty {
                        HStack { Text("最近写过").font(.headline); Spacer(); Button("清空") { recent = "" } }
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 65))]) {
                            ForEach(Question.letters(recent)) { letter in Button(letter.text) { open(letter) }.font(.largeTitle).padding(10).foregroundStyle(green) }
                        }
                    }
                    Text("没有广告 · 不需要账号 · 字形与笔顺可离线查看").font(.footnote).foregroundStyle(.secondary)
                }.padding(24).frame(maxWidth: 760)
                    .frame(maxWidth: .infinity)
            }.background(Color(red: 0.96, green: 0.96, blue: 0.92))
                .fullScreenCover(item: $selected) { letter in WritingView(letter: letter) }
        }
        .onChange(of: speech.transcript) { value in if !value.isEmpty { question = value } }
        .onChange(of: scenePhase) { value in if value != .active { speech.stop() } }
    }
    private func find() {
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
