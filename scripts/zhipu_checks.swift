// No live credentials or provider calls: verify the wire contract and responses.
let request = try ZhipuClient.request(key: "unit-test-placeholder", input: "我想喝水", task: .chineseToEnglish, audience: .child, scene: "在家", history: [])
assert(request.url == ZhipuClient.endpoint)
assert(request.httpMethod == "POST")
assert(request.value(forHTTPHeaderField: "Authorization") == "Bearer unit-test-placeholder")
let body = try JSONSerialization.jsonObject(with: request.httpBody!) as! [String: Any]
assert(body["model"] as? String == "glm-4.7-flash")
assert(body["stream"] as? Bool == false)
assert((body["thinking"] as? [String: String])?["type"] == "disabled")
assert((body["response_format"] as? [String: String])?["type"] == "json_object")
let messages = body["messages"] as! [[String:String]]
assert(messages.count == 2 && messages[0]["role"] == "system")
assert(!String(decoding: request.httpBody!, as: UTF8.self).contains("unit-test-placeholder"))
let user = try JSONSerialization.jsonObject(with: Data(messages[1]["content"]!.utf8)) as! [String:String]
assert(user["utterance"] == "我想喝水" && user["task"] == "chineseToEnglish")
let history = (0..<20).map { TutorMessage(role: $0 % 2 == 0 ? "user" : "assistant", content: "context-\($0)") }
let chat = try ZhipuClient.request(key: "unit-test-placeholder", input: "Hi!", task: .conversation, audience: .adult, scene: "去公园", history: history)
let chatBody = try JSONSerialization.jsonObject(with: chat.httpBody!) as! [String:Any]
assert((chatBody["messages"] as! [[String:String]]).count == 14)
let standalone = try ZhipuClient.request(key: "unit-test-placeholder", input: "Hello.", task: .englishToChinese, audience: .child, scene: "学校", history: history)
let standaloneMessages = ((try JSONSerialization.jsonObject(with: standalone.httpBody!)) as! [String:Any])["messages"] as! [[String:String]]
assert(standaloneMessages.count == 2)
let answer = TutorReply(english: "I went to the park yesterday.", chinese: "我昨天去了公园。", status: .needs_correction, corrections: [TutorCorrection(before:"go", after:"went", reason:"昨天发生的事，用过去式。")], alternative:"", tip:"注意过去式。", replyEnglish:"", replyChinese:"")
func envelope(_ reply: TutorReply, finish: String = "stop") throws -> Data {
    let json = String(decoding: try JSONEncoder().encode(reply), as: UTF8.self)
    return try JSONSerialization.data(withJSONObject: ["choices":[["message":["content":json,"reasoning_content":"must not be displayed"],"finish_reason":finish]]])
}
let decodedAnswer = try ZhipuClient.decode(envelope(answer), status:200, task:.englishToChinese)
assert(decodedAnswer == answer)
func expect(_ error: TutorError, _ action: () throws -> Void) {
    do { try action(); fatalError("Expected \(error)") } catch let actual as TutorError { assert(actual == error) } catch { fatalError("Unexpected error") }
}
expect(.unauthorized) { _ = try ZhipuClient.decode(Data(), status:401, task:.englishToChinese) }
expect(.forbidden) { _ = try ZhipuClient.decode(Data(), status:403, task:.englishToChinese) }
expect(.rateLimited) { _ = try ZhipuClient.decode(Data(), status:429, task:.englishToChinese) }
expect(.unavailable) { _ = try ZhipuClient.decode(Data(), status:500, task:.englishToChinese) }
expect(.malformed) { _ = try ZhipuClient.decode(Data("not json".utf8), status:200, task:.englishToChinese) }
expect(.truncated) { _ = try ZhipuClient.decode(envelope(answer, finish:"length"), status:200, task:.englishToChinese) }
expect(.refused) { _ = try ZhipuClient.decode(envelope(answer, finish:"content_filter"), status:200, task:.englishToChinese) }
expect(.malformed) { _ = try answer.validated(for: .chineseToEnglish) }
expect(.malformed) { _ = try answer.validated(for: .conversation) }
expect(.missingKey) { _ = try ZhipuClient.request(key:"bad\nkey", input:"hi", task:.conversation, audience:.child, scene:"在家", history:[]) }
expect(.invalidInput) { _ = try ZhipuClient.request(key:"unit-test-placeholder", input:String(repeating:"a",count:1001), task:.conversation, audience:.child, scene:"在家", history:[]) }
print("Zhipu free-model request contract, structured feedback, context boundaries and error handling passed; no live API called")
