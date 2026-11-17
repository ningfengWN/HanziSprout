import SwiftUI
import Combine

struct DailyTaskItem: Codable, Identifiable {
    var id: String
    var title: String
    var completed = false
    var minutes: Int? = nil
    var custom = false
    var startedAt: Date? = nil
    var recordedSeconds: Int? = nil

    var savedSeconds: Int { max(0, recordedSeconds ?? ((minutes ?? 0) * 60)) }
    func seconds(at date: Date) -> Int {
        let elapsed = startedAt.map { max(0, Int(date.timeIntervalSince($0))) } ?? 0
        return savedSeconds + elapsed
    }
    func durationText(at date: Date) -> String {
        let total = seconds(at: date)
        return String(format: "%d:%02d", total / 60, total % 60)
    }
    mutating func toggleTimer(at date: Date) {
        if startedAt != nil {
            recordedSeconds = seconds(at: date)
            minutes = savedSeconds / 60
            startedAt = nil
        } else { startedAt = date }
    }
}

struct DailyTaskBook: Codable {
    var days: [String: [DailyTaskItem]] = [:]
    static let fixedTitles = ["语文", "数学", "跳绳", "阅读", "英语", "五星学霸", "口算练习"]
    static func defaults() -> [DailyTaskItem] {
        fixedTitles.enumerated().map { DailyTaskItem(id: "fixed-\($0.offset)", title: $0.element) }
    }
    static func dayKey(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
    func items(on date: Date) -> [DailyTaskItem] { days[Self.dayKey(date)] ?? Self.defaults() }
}

struct DailyTasksView: View {
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("dailyTasks.book.v1") private var stored = Data()
    @State private var selectedDate = Date()
    @State private var followsToday = true
    @State private var newTitle = ""
    @State private var editingTime: DailyTaskItem?
    @State private var pendingUncheck: DailyTaskItem?
    @State private var minuteText = ""
    @FocusState private var titleFocused: Bool
    @FocusState private var minutesFocused: Bool
    private let clock = Timer.publish(every: 30, on: .main, in: .common).autoconnect()
    private var book: DailyTaskBook { (try? JSONDecoder().decode(DailyTaskBook.self, from: stored)) ?? DailyTaskBook() }
    private var items: [DailyTaskItem] { book.items(on: selectedDate) }
    private var completed: Int { items.filter(\.completed).count }

    var body: some View {
        NavigationStack {
            ZStack {
                PaperBackground()
                ViewThatFits(in: .vertical) {
                    checklist
                    ScrollView { checklist }
                }.padding(.horizontal, 16)
            }
            .foregroundStyle(Crayon.ink)
            .navigationTitle("每日任务")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("完成") { titleFocused = false; minutesFocused = false }
            } }
            .alert("取消完成状态？", isPresented: Binding(
                get: { pendingUncheck != nil },
                set: { if !$0 { pendingUncheck = nil } }
            ), presenting: pendingUncheck) { item in
                Button("保留完成", role: .cancel) { pendingUncheck = nil }
                Button("确认取消", role: .destructive) {
                    update(item.id) { $0.completed = false }
                    pendingUncheck = nil
                }
            } message: { item in
                Text("确定取消“\(item.title)”的完成勾选吗？已记录的用时会保留。")
            }
            .sheet(item: $editingTime) { item in timeEditor(item) }
        }
        .onReceive(clock) { _ in refreshToday() }
        .onChange(of: scenePhase) { if $0 == .active { refreshToday() } }
    }
    private var checklist: some View {
        VStack(spacing: 10) {
            dateHeader
            HStack {
                Text("已完成 \(completed)/\(items.count) 项").font(.subheadline.bold())
                Spacer()
                Text("已记录 \(items.reduce(0) { $0 + $1.savedSeconds } / 60) 分钟").font(.caption)
            }
            VStack(spacing: 0) {
                ForEach(items) { item in
                    taskRow(item)
                    if item.id != items.last?.id { Divider().padding(.horizontal, 12) }
                }
            }.crayonCard(.white)
            HStack(spacing: 8) {
                TextField("添加临时任务", text: $newTitle)
                    .textFieldStyle(.roundedBorder).focused($titleFocused)
                    .submitLabel(.done).onSubmit(addTask)
                Button("添加", action: addTask).buttonStyle(.borderedProminent).tint(Crayon.green)
                    .disabled(newTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            Text("点开始计时，结束后自动累计用时；点用时可手动修改。").font(.caption).foregroundStyle(.secondary)
        }.padding(.vertical, 8).frame(maxWidth: 700).frame(maxWidth: .infinity)
    }
    private var dateHeader: some View {
        HStack(spacing: 10) {
            Button { moveDay(-1) } label: { Image(systemName: "chevron.left").frame(width: 32, height: 40) }
                .accessibilityLabel("前一天")
            DatePicker("日期", selection: Binding(get: { selectedDate }, set: {
                selectedDate = $0; followsToday = Calendar.current.isDateInToday($0)
            }), displayedComponents: .date).labelsHidden()
            Button { moveDay(1) } label: { Image(systemName: "chevron.right").frame(width: 32, height: 40) }
                .accessibilityLabel("后一天")
            Spacer(minLength: 0)
            Button("今天") { selectedDate = Date(); followsToday = true }
        }.buttonStyle(.plain)
    }
    private func taskRow(_ item: DailyTaskItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                titleFocused = false
                if item.completed { pendingUncheck = item }
                else { update(item.id) { $0.completed = true } }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: item.completed ? "checkmark.square.fill" : "square")
                        .font(.system(size: 26)).foregroundStyle(Crayon.green)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title).font(.body.weight(.medium)).strikethrough(item.completed)
                            .foregroundStyle(Crayon.ink).lineLimit(1)
                        if item.startedAt != nil {
                            TimelineView(.periodic(from: .now, by: 1)) { context in
                                Text("计时中 " + item.durationText(at: context.date))
                                    .font(.caption).monospacedDigit().foregroundStyle(Crayon.green)
                            }
                        }
                    }
                    Spacer(minLength: 0)
                }.frame(minHeight: 44).contentShape(Rectangle())
            }.buttonStyle(.plain)
                .accessibilityLabel("\(item.title)，\(item.completed ? "已完成" : "未完成")，点击切换")
            HStack(spacing: 18) {
            Button(item.startedAt == nil ? "开始" : "结束") {
                titleFocused = false
                update(item.id) { $0.toggleTimer(at: Date()) }
            }.frame(minWidth: 64, minHeight: 44).buttonStyle(.bordered).tint(item.startedAt == nil ? Crayon.green : .red)
                .accessibilityLabel("\(item.title)\(item.startedAt == nil ? "开始计时" : "结束计时")")
            Button {
                titleFocused = false
                minuteText = item.minutes.map(String.init) ?? ""
                editingTime = item
            } label: {
                Text(item.recordedSeconds != nil ? item.durationText(at: item.startedAt ?? Date()) : (item.minutes.map { "\($0)分钟" } ?? "用时"))
                    .font(.subheadline).foregroundStyle(Crayon.green).frame(minWidth: 48, minHeight: 44)
            }.buttonStyle(.plain).disabled(item.startedAt != nil).accessibilityLabel("\(item.title)用时，计时结束后可修改")
            Spacer(minLength: 0)
            if item.custom {
                Button(role: .destructive) { save(items.filter { $0.id != item.id }) } label: {
                    Image(systemName: "minus.circle").frame(width: 30, height: 44)
                }.buttonStyle(.plain).accessibilityLabel("删除\(item.title)")
            }
            }.padding(.leading, 38)
        }.padding(.horizontal, 12).padding(.vertical, 8)
    }
    private func timeEditor(_ item: DailyTaskItem) -> some View {
        NavigationStack {
            Form {
                Section("\(item.title) · 用时") {
                    TextField("分钟数，可留空", text: $minuteText)
                        .keyboardType(.numberPad).focused($minutesFocused)
                    Text("填写 0–1440 分钟；留空表示不记录用时。")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section {
                    Button("完成并保存") { saveTime(item) }.disabled(!validMinutes)
                    Button("不记录用时") { minuteText = ""; saveTime(item) }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("记录用时").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { minutesFocused = false; editingTime = nil }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { saveTime(item) }.disabled(!validMinutes)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("收起键盘") { minutesFocused = false }
                }
            }
        }.presentationDetents([.medium, .large])
    }
    private var validMinutes: Bool {
        let text = minuteText.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty || Int(text).map { (0...1440).contains($0) } == true
    }
    private func saveTime(_ item: DailyTaskItem) {
        guard validMinutes else { return }
        let text = minuteText.trimmingCharacters(in: .whitespacesAndNewlines)
        update(item.id) {
            $0.minutes = text.isEmpty ? nil : Int(text)
            $0.recordedSeconds = text.isEmpty ? nil : (Int(text) ?? 0) * 60
        }
        minutesFocused = false; editingTime = nil
    }
    private func save(_ values: [DailyTaskItem]) {
        var next = book
        next.days[DailyTaskBook.dayKey(selectedDate)] = values
        if let encoded = try? JSONEncoder().encode(next) { stored = encoded }
    }
    private func update(_ id: String, change: (inout DailyTaskItem) -> Void) {
        var next = items
        guard let index = next.firstIndex(where: { $0.id == id }) else { return }
        change(&next[index]); save(next)
    }
    private func addTask() {
        let title = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { titleFocused = false; return }
        var next = items
        next.append(DailyTaskItem(id: UUID().uuidString, title: title, custom: true))
        save(next); newTitle = ""; titleFocused = false
    }
    private func moveDay(_ delta: Int) {
        guard let date = Calendar.current.date(byAdding: .day, value: delta, to: selectedDate) else { return }
        titleFocused = false; selectedDate = date
        followsToday = Calendar.current.isDateInToday(date)
    }
    private func refreshToday() {
        if followsToday && !Calendar.current.isDateInToday(selectedDate) { selectedDate = Date() }
    }
}
