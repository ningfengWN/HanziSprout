import Foundation

enum OpenAITutorError: Error, LocalizedError, Equatable {
    case missingKey, invalidInput, unauthorized, forbidden, region, quota, rateLimited, unavailable, modelUnavailable, invalidRequest, malformed, truncated, refused
    var errorDescription: String? {
        switch self {
        case .missingKey: return "请在 AI 设置中选择 OpenAI，保存 OpenAI API Key 并启用。智谱密钥不能用于 OpenAI。"
        case .invalidInput: return "请输入一句话，最多 1,000 个字符。"
        case .unauthorized: return "OpenAI 密钥无效、过期或已撤销。请在 AI 设置中重新保存有效的 OpenAI Key。"
        case .forbidden: return "OpenAI 拒绝访问。请核对 Key 的 Responses 写入权限，以及项目、模型和组织权限。"
        case .region: return "OpenAI 返回地区访问限制，请查看官方支持地区。仅有 API 额度不代表实际使用地区受到支持。"
        case .quota: return "OpenAI 返回额度不足或用量限制。当前 API 组织可能额度不足、额度过期或达到项目用量限制。请处理账户后再试；App 不会自动充值。"
        case .rateLimited: return "OpenAI 请求达到速率限制，请等待后手动重试。不会自动换模型或切换到智谱。"
        case .unavailable: return "OpenAI 暂时未完成请求，请稍后重试；离线功能仍可使用。"
        case .modelUnavailable: return "当前 OpenAI 项目无法使用 GPT-6 Luna。请在平台核对该组织和项目的模型权限；不会自动切换其他模型。"
        case .invalidRequest: return "OpenAI 未接受请求参数，请确认使用最新版 App。密钥如设置了限制，需要允许 Responses 写入。"
        case .malformed: return "OpenAI 回答格式不完整，请重新发送。"
        case .truncated: return "OpenAI 回答达到长度上限，请缩短句子后重试。"
        case .refused: return "这次内容未得到可用的学习回答，请换一句日常表达再试。"
        }
    }
    var cooldown: TimeInterval { self == .rateLimited ? 20 : 0 }
}
private final class OpenAINoRedirects: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) { completionHandler(nil) }
}
struct OpenAIClient {
    static let model = "gpt-6-luna"
    static let endpoint = URL(string: "https://api.openai.com/v1/responses")!
    let session: URLSession
    init(session: URLSession? = nil) {
        if let session { self.session = session }
        else {
            let config = URLSessionConfiguration.ephemeral
            config.urlCache = nil; config.httpCookieStorage = nil
            config.timeoutIntervalForRequest = 45; config.timeoutIntervalForResource = 60
            self.session = URLSession(configuration: config, delegate: OpenAINoRedirects(), delegateQueue: nil)
        }
    }
    static var schema: [String: Any] {
        let string: [String: Any] = ["type":"string"]
        let correction: [String: Any] = [
            "type":"object", "additionalProperties":false,
            "properties":["before":string,"after":string,"reason":string],
            "required":["before","after","reason"]
        ]
        return [
            "type":"object", "additionalProperties":false,
            "properties":[
                "english":string, "chinese":string,
                "status":["type":"string","enum":["translation","correct","needs_correction","unclear"]],
                "corrections":["type":"array","items":correction],
                "alternative":string, "tip":string, "replyEnglish":string, "replyChinese":string
            ],
            "required":["english","chinese","status","corrections","alternative","tip","replyEnglish","replyChinese"]
        ]
    }
    static func request(key: String, input: String, task: TutorTask, audience: TutorAudience, scene: String, history: [TutorMessage]) throws -> URLRequest {
        let key = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty, key.count <= 512, !key.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) || CharacterSet.whitespacesAndNewlines.contains($0) }) else { throw OpenAITutorError.missingKey }
        let input = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty, input.count <= 1000 else { throw OpenAITutorError.invalidInput }
        var messages: [[String: String]] = []
        if task == .conversation {
            messages = history.filter { ["user","assistant"].contains($0.role) && $0.content.count <= 12000 }.suffix(12).map { ["role":$0.role,"content":$0.content] }
        }
        let payload = try JSONSerialization.data(withJSONObject: ["task":task.rawValue,"utterance":input])
        messages.append(["role":"user", "content":String(decoding: payload, as: UTF8.self)])
        let body: [String: Any] = [
            "model":model, "instructions":TutorPrompt.system(audience: audience, scene: scene),
            "input":messages, "store":false, "stream":false,
            "reasoning":["effort":"none"], "max_output_tokens":1600,
            "text":["format":["type":"json_schema","name":"sprout_english_feedback","strict":true,"schema":schema]]
        ]
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"; request.timeoutInterval = 45
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }
    static func error(status: Int, code: String?) -> OpenAITutorError {
        switch code {
        case "insufficient_quota", "credit_balance_exhausted", "billing_hard_limit_reached", "usage_limit_reached": return .quota
        case "unsupported_country_region_territory": return .region
        case "model_not_found": return .modelUnavailable
        case "rate_limit_exceeded": return .rateLimited
        case "invalid_api_key": return .unauthorized
        default: break
        }
        switch status {
        case 400, 422: return .invalidRequest
        case 401: return .unauthorized
        case 403: return .forbidden
        case 404: return .modelUnavailable
        case 429: return .rateLimited
        default: return .unavailable
        }
    }
    static func decode(_ data: Data, status: Int, task: TutorTask) throws -> TutorReply {
        guard data.count <= 256_000 else { throw OpenAITutorError.malformed }
        let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        if status != 200 {
            let detail = object?["error"] as? [String: Any]
            throw error(status: status, code: detail?["code"] as? String)
        }
        if object?["status"] as? String == "failed" {
            let detail = object?["error"] as? [String: Any]
            throw error(status: 500, code: detail?["code"] as? String)
        }
        if object?["status"] as? String == "incomplete" {
            let details = object?["incomplete_details"] as? [String: Any]
            if details?["reason"] as? String == "max_output_tokens" { throw OpenAITutorError.truncated }
            throw OpenAITutorError.refused
        }
        guard object?["status"] as? String == "completed", let output = object?["output"] as? [[String: Any]] else { throw OpenAITutorError.malformed }
        var text = ""
        for item in output where item["type"] as? String == "message" && item["role"] as? String == "assistant" {
            for content in item["content"] as? [[String: Any]] ?? [] {
                if content["type"] as? String == "refusal" { throw OpenAITutorError.refused }
                if content["type"] as? String == "output_text", let part = content["text"] as? String { text += part }
            }
        }
        guard !text.isEmpty, let payload = text.data(using: .utf8), let reply = try? JSONDecoder().decode(TutorReply.self, from: payload) else { throw OpenAITutorError.malformed }
        do { return try reply.validated(for: task) } catch { throw OpenAITutorError.malformed }
    }
    func answer(key: String, input: String, task: TutorTask, audience: TutorAudience, scene: String, history: [TutorMessage]) async throws -> TutorReply {
        let request = try Self.request(key: key, input: input, task: task, audience: audience, scene: scene, history: history)
        let (data, response) = try await session.data(for: request)
        try Task.checkCancellation()
        guard let response = response as? HTTPURLResponse else { throw OpenAITutorError.unavailable }
        return try Self.decode(data, status: response.statusCode, task: task)
    }
}
