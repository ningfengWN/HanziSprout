import SwiftUI

struct TutorTurn: Identifiable {
    let id = UUID()
    let input: String
    let answer: TutorReply
}
@MainActor
final class TutorModel: ObservableObject {
    @Published private(set) var loading = false
    @Published private(set) var error: String?
    @Published private(set) var turns: [TutorTurn] = []
    private var history: [TutorMessage] = []
    private var work: Task<Void, Never>?
    private var generation = 0
    private let client = ZhipuClient()

    func send(_ input: String, task: TutorTask, audience: TutorAudience, scene: String) {
        guard !loading else { return }
        error = nil
        let key: String
        do {
            guard let stored = try APIKeyStore.read(), !stored.isEmpty else { throw TutorError.missingKey }
            key = stored
        } catch { self.error = error.localizedDescription; return }
        let context = task == .conversation ? history : []
        let token = generation
        loading = true
        work = Task { @MainActor [weak self] in
            do {
                guard let self else { return }
                let reply = try await self.client.answer(key: key, input: input, task: task, audience: audience, scene: scene, history: context)
                guard !Task.isCancelled, self.generation == token else { return }
                let turn = TutorTurn(input: input, answer: reply)
                if task == .conversation {
                    self.turns.append(turn)
                    self.turns = Array(self.turns.suffix(6))
                    let user = try JSONSerialization.data(withJSONObject: ["task":task.rawValue, "utterance":input])
                    let assistant = try JSONEncoder().encode(reply)
                    self.history += [TutorMessage(role: "user", content: String(decoding: user, as: UTF8.self)), TutorMessage(role: "assistant", content: String(decoding: assistant, as: UTF8.self))]
                    self.history = Array(self.history.suffix(12))
                } else { self.turns = [turn]; self.history = [] }
                self.loading = false
            } catch {
                guard let self, !Task.isCancelled, self.generation == token else { return }
                self.loading = false
                if let known = error as? TutorError { self.error = known.localizedDescription }
                else if let network = error as? URLError, network.code == .timedOut { self.error = "等待回答超时，请稍后重试。" }
                else { self.error = "请求未完成，请检查网络后重试。离线功能仍可使用。" }
            }
        }
    }
    func cancel() { generation += 1; work?.cancel(); work = nil; loading = false }
    func reset() { cancel(); error = nil; turns = []; history = [] }
}
