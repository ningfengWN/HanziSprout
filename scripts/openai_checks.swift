// Contract checks only; no account key or network calls.
assert(AIProvider.zhipu.keychainService == "com.ningfeng.HanziSprout.zhipu")
assert(AIProvider.openai.keychainService != AIProvider.zhipu.keychainService)
let request = try OpenAIClient.request(key: "test-placeholder", input: "我想喝水", task: .chineseToEnglish, audience: .child, scene: "在家", history: [])
assert(request.url?.absoluteString == "https://api.openai.com/v1/responses")
assert(request.httpMethod == "POST")
assert(request.value(forHTTPHeaderField: "Authorization") == "Bearer test-placeholder")
let body = try JSONSerialization.jsonObject(with: request.httpBody!) as! [String:Any]
assert(body["model"] as? String == AIProvider.openai.modelName)
assert(body["store"] as? Bool == false && body["stream"] as? Bool == false)
assert(body["tools"] == nil && body["previous_response_id"] == nil)
assert((body["reasoning"] as! [String:String])["effort"] == "none")
let format = (body["text"] as! [String:Any])["format"] as! [String:Any]
assert(format["type"] as? String == "json_schema" && format["strict"] as? Bool == true)
let schema = format["schema"] as! [String:Any]
assert(schema["additionalProperties"] as? Bool == false)
assert(Set(schema["required"] as! [String]) == Set((schema["properties"] as! [String:Any]).keys))
assert(!String(decoding: request.httpBody!, as: UTF8.self).contains("test-placeholder"))
let history = (0..<20).map { TutorMessage(role: $0 % 2 == 0 ? "user" : "assistant", content: "context-\($0)") }
for task in [TutorTask.conversation, .englishToChinese] {
    let r = try OpenAIClient.request(key:"test-placeholder", input:"Hello", task:task, audience:.adult, scene:"在家", history:history)
    let b = try JSONSerialization.jsonObject(with:r.httpBody!) as! [String:Any]
    assert((b["input"] as! [[String:String]]).count == (task == .conversation ? 13 : 1))
}
let reply = TutorReply(english:"I want some water.", chinese:"我想喝水。", status:.translation, corrections:[], alternative:"", tip:"", replyEnglish:"", replyChinese:"")
let json = String(decoding:try JSONEncoder().encode(reply), as:UTF8.self)
func data(_ value: [String:Any]) throws -> Data { try JSONSerialization.data(withJSONObject:value) }
let result = try data(["status":"completed", "output":[["type":"reasoning","summary":["private"]], ["type":"message","role":"assistant","content":[["type":"output_text","text":json]]]]])
let decoded = try OpenAIClient.decode(result, status:200, task:.chineseToEnglish)
assert(decoded == reply)
func expect(_ error:OpenAITutorError, _ action:() throws -> Void) {
    do { try action(); fatalError("Expected \(error)") } catch let actual as OpenAITutorError { assert(actual == error) } catch { fatalError("Unexpected error") }
}
expect(.quota) { _ = try OpenAIClient.decode(data(["error":["code":"insufficient_quota"]]), status:429, task:.chineseToEnglish) }
expect(.rateLimited) { _ = try OpenAIClient.decode(data(["error":["code":"rate_limit_exceeded"]]), status:429, task:.chineseToEnglish) }
expect(.forbidden) { _ = try OpenAIClient.decode(Data(), status:403, task:.chineseToEnglish) }
expect(.truncated) { _ = try OpenAIClient.decode(data(["status":"incomplete","incomplete_details":["reason":"max_output_tokens"]]), status:200, task:.chineseToEnglish) }
expect(.refused) { _ = try OpenAIClient.decode(data(["status":"completed","output":[["type":"message","role":"assistant","content":[["type":"refusal","refusal":"No"]]]]]), status:200, task:.chineseToEnglish) }
expect(.malformed) { _ = try OpenAIClient.decode(result, status:200, task:.conversation) }
expect(.missingKey) { _ = try OpenAIClient.request(key:"bad\nkey", input:"hi", task:.conversation, audience:.child, scene:"在家", history:[]) }
expect(.invalidInput) { _ = try OpenAIClient.request(key:"test-placeholder", input:String(repeating:"a",count:1001), task:.conversation, audience:.child, scene:"在家", history:[]) }
print("OpenAI Responses schema, feedback, context, provider isolation and quota errors passed; no live API called")
