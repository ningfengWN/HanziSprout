import SwiftUI

struct AISettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("zhipuEnabled") private var enabled = false
    @State private var newKey = ""
    @State private var hasKey = false
    @State private var error: String?
    var body: some View {
        NavigationStack {
            Form {
                Section("智谱免费文本模型") {
                    Text("固定使用 GLM-4.7-Flash，不自动切换到其他型号。")
                    Text("当前官方输入、输出免费；平台政策及调用频率限制以智谱为准。")
                        .font(.caption).foregroundStyle(.secondary)
                    Toggle("启用 AI 翻译、纠错和陪练", isOn: $enabled)
                        .disabled(!hasKey)
                }
                Section("模型标准 API Key") {
                    Text(hasKey ? "已保存在本机钥匙串；输入新 Key 可替换。" : "还没有保存密钥。")
                    SecureField("粘贴模型标准 API Key", text: $newKey)
                        .textContentType(.password).textInputAutocapitalization(.never).autocorrectionDisabled()
                        .privacySensitive()
                    Button("保存并启用") {
                        do { try APIKeyStore.save(newKey); newKey = ""; hasKey = true; enabled = true; error = nil }
                        catch { self.error = error.localizedDescription }
                    }.disabled(newKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    if hasKey {
                        Button("删除密钥并关闭 AI", role: .destructive) {
                            do { try APIKeyStore.delete(); enabled = false; hasKey = false; newKey = ""; error = nil }
                            catch { self.error = error.localizedDescription }
                        }
                    }
                    if let error { Text(error).foregroundStyle(.red) }
                }
                Section("如何申请") {
                    Link("打开智谱 API Keys 管理页", destination: URL(string: "https://bigmodel.cn/usercenter/proj-mgmt/apikeys")!)
                    Text("注册登录后，创建“模型标准 API”密钥；Coding Plan 的个人、团队套餐密钥不通用。不要把密钥发到聊天或提交到 GitHub。")
                        .font(.callout)
                }
                Section("发送与保存") {
                    Text("点击 AI 页的发送，或开启自动发送后说完，识别出的文字会通过 HTTPS 发给智谱。App 不向智谱上传录音。对话模式会附带当前会话最近 6 轮文字。")
                    Text("密钥保存在当前设备的系统钥匙串，不写入代码、UserDefaults 或对话记录。当前是家庭自用的自带密钥模式；多人公开分发应改为后台保管平台密钥。")
                    Text("AI 可能误译或误判语法；这里的文字纠错不等于发音评测。")
                }.font(.callout)
            }.foregroundStyle(Crayon.ink).tint(Crayon.green).preferredColorScheme(.light)
                .navigationTitle("AI 设置")
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } } }
                .onAppear {
                    do { hasKey = try APIKeyStore.read() != nil; if !hasKey { enabled = false } }
                    catch { self.error = error.localizedDescription; enabled = false }
                }
                .onDisappear { newKey = "" }
        }
    }
}
