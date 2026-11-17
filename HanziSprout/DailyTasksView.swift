import SwiftUI
import Combine

struct DailyTaskItem: Codable, Identifiable {
    var id: String
    var title: String
    var completed = false
    var minutes: Int? = nil
    var custom = false
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
    @FocusState private var titleFocused: Bool

    private var book: DailyTaskBook { (try? JSONDecoder().decode(DailyTaskBook.self, from: stored)) ?? DailyTaskBook() }
    private var items: [DailyTaskItem] { book.items(on: selectedDate) }
    private var completed: Int { items.filter(\.completed).count }
    private let clock = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            ZStack {
                PaperBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        dateHeader
                        progressCard
                        VStack(spacing: 12) {
                            ForEach(items) { item in taskRow(item) }
                        }
                        addTaskCard
                        Text("固定任务每天自动生成；临时任务仅加入选中的日期。打勾与用时分别记录，用时可留空。记录保存在本机。")
                            .font(.footnote).foregroundStyle(.secondary)
                    }.padding().frame(maxWidth: 760).frame(maxWidth: .infinity)
                }.scrollDismissesKeyboard(.interactively)
            }.foregroundStyle(Crayon.ink)
                .navigationTitle("每日任务")
                .toolbar { ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("收起键盘") { titleFocused = false } } }
        }
        .onReceive(clock) { _ in refreshToday() }
        .onChange(of: scenePhase) { if $0 == .active { refreshToday() } }
    }

    private var dateHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            DatePicker("任务日期", selection: Binding(get: { selectedDate }, set: {
                selectedDate = $0; followsToday = Calendar.current.isDateInToday($0)
            }), displayedComponents: .date)
            HStack {
                Button("前一天") { moveDay(-1) }
                Spacer()
                Button("今天") { selectedDate = Date(); followsToday = true }
                Spacer()
                Button("后一天") { moveDay(1) }
            }.buttonStyle(.bordered)
        }
    }
    private var progressCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(completed == items.count ? "今天的任务都完成啦！" : "一步一步完成今天的小目标")
                .font(.headline)
            ProgressView(value: Double(completed), total: Double(max(1, items.count))).tint(Crayon.green)
            Text("已完成 \(completed) / \(items.count) 项 · 已记录用时 \(items.compactMap(\.minutes).reduce(0, +)) 分钟")
                .font(.subheadline)
        }.padding(18).crayonCard(Crayon.yellow)
    }
    private func taskRow(_ item: DailyTaskItem) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Button { update(item.id) { $0.completed.toggle() } } label: {
                    Image(systemName: item.completed ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 30)).foregroundStyle(Crayon.green)
                        .frame(width: 44, height: 44)
                }.buttonStyle(.plain)
                    .accessibilityLabel("\(item.title)，\(item.completed ? "已完成，点击取消" : "未完成，点击打勾")")
                Text(item.title).font(.title3.bold()).strikethrough(item.completed)
                Spacer()
                if item.custom {
                    Button(role: .destructive) { delete(item.id) } label: { Image(systemName: "trash") }
                        .accessibilityLabel("删除临时任务\(item.title)")
                }
            }
            Toggle("记录用时", isOn: Binding(get: { item.minutes != nil }, set: { enabled in
                update(item.id) { $0.minutes = enabled ? 0 : nil }
            })).font(.subheadline)
            if let minutes = item.minutes {
                Stepper("用时 \(minutes) 分钟", value: Binding(get: { minutes }, set: { value in
                    update(item.id) { $0.minutes = value }
                }), in: 0...1440, step: 5)
                TextField("输入分钟数", text: Binding(get: { String(minutes) }, set: { value in
                    guard let number = Int(value), (0...1440).contains(number) else { return }
                    update(item.id) { $0.minutes = number }
                })).keyboardType(.numberPad).textFieldStyle(.roundedBorder)
                    .accessibilityLabel("\(item.title)用时，分钟")
            }
        }.padding(16).crayonCard(item.completed ? Crayon.blue : .white)
    }
    private var addTaskCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("临时任务").font(.headline)
            TextField("输入今天临时增加的任务", text: $newTitle).focused($titleFocused)
                .textFieldStyle(.roundedBorder).submitLabel(.done).onSubmit(addTask)
            Button("添加任务", action: addTask).buttonStyle(CrayonButtonStyle())
                .disabled(newTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }.padding(18).crayonCard(Crayon.peach)
    }
    private func save(_ items: [DailyTaskItem]) {
        var next = book
        next.days[DailyTaskBook.dayKey(selectedDate)] = items
        if let encoded = try? JSONEncoder().encode(next) { stored = encoded }
    }
    private func update(_ id: String, change: (inout DailyTaskItem) -> Void) {
        var next = items
        guard let index = next.firstIndex(where: { $0.id == id }) else { return }
        change(&next[index]); save(next)
    }
    private func delete(_ id: String) { save(items.filter { $0.id != id || !$0.custom }) }
    private func addTask() {
        let title = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        var next = items
        next.append(DailyTaskItem(id: UUID().uuidString, title: title, custom: true))
        save(next); newTitle = ""; titleFocused = false
    }
    private func moveDay(_ delta: Int) {
        guard let date = Calendar.current.date(byAdding: .day, value: delta, to: selectedDate) else { return }
        selectedDate = date; followsToday = Calendar.current.isDateInToday(date)
    }
    private func refreshToday() {
        if followsToday && !Calendar.current.isDateInToday(selectedDate) { selectedDate = Date() }
    }
}
