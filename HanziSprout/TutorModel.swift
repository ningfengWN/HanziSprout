import SwiftUI

struct TutorTurn: Identifiable {
    let id = UUID()
    let input: String
    let answer: TutorReply
}
@MainActor
final class TutorModel: ObservableObject {
    @Published private(set) var loading = false
    @Published private(set) var quotaReached = false
    @Published private(set) var error: String?
    @Published private(set) var turns: [TutorTurn] = []
    @Published private(set) var nextAllowedAt: Date?
    var canSend: Bool { !quotaReached && !loading && (nextAllowedAt.map { $0 <= Date() } ?? true) }
    private var history: [TutorMessage] = []
    private var work: Task<Void, Never>?
    private var generation = 0
    private let zhipu = ZhipuClient()
    private let openai = OpenAIClient()

    func send(_ input: String, provider: AIProvider, task: TutorTask, audience: TutorAudience, scene: String) {
        guard canSend else { return }
        error = nil
        let key: String
        do {
            guard let stored = try APIKeyStore.read(provider: provider), !stored.isEmpty else {
                if provider == .openai { throw OpenAITutorError.missingKey }
                throw TutorError.missingKey
            }
            key = stored
        } catch { self.error = error.localizedDescription; return }
        let context = task == .conversation ? history : []
        let token = generation
        loading = true
        work = Task { @MainActor [weak self] in
            do {
                guard let self else { return }
                let reply: TutorReply
                switch provider {
                case .zhipu: reply = try await self.zhipu.answer(key: key, input: input, task: task, audience: audience, scene: scene, history: context)
                case .openai: reply = try await self.openai.answer(key: key, input: input, task: task, audience: audience, scene: scene, history: context)
                }
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
                if let known = error as? TutorError {
                    self.error = known.localizedDescription
                    if case .provider(_, let code) = known { self.quotaReached = [1113, 1304, 1308, 1310].contains(code) || (1316...1321).contains(code) }
                    if known.cooldown > 0 { self.nextAllowedAt = Date().addingTimeInterval(known.cooldown) }
                }
                else if let known = error as? OpenAITutorError {
                    self.quotaReached = known == .quota
                    self.error = known.localizedDescription
                    if known.cooldown > 0 { self.nextAllowedAt = Date().addingTimeInterval(known.cooldown) }
                }
                else if let network = error as? URLError, network.code == .timedOut { self.error = "等待回答超时，请稍后重试。" }
                else { self.error = "请求未完成，请检查网络后重试。离线功能仍可使用。" }
            }
        }
    }
    func resumeAfterQuota() { quotaReached = false; error = nil }
    func cancel() { generation += 1; work?.cancel(); work = nil; loading = false }
    func reset(clearCooldown: Bool = false) { cancel(); if !quotaReached { error = nil }; turns = []; history = []; if clearCooldown { nextAllowedAt = nil; quotaReached = false; error = nil } }
}
