import SwiftUI

struct AISettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("aiProvider") private var providerRaw = AIProvider.zhipu.rawValue
    @AppStorage("zhipuEnabled") private var zhipuEnabled = false
    @AppStorage("openAIEnabled") private var openAIEnabled = false
    @State private var newKey = ""
    @State private var hasKey = false
    @State private var error: String?
    private var provider: AIProvider { AIProvider(rawValue: providerRaw) ?? .zhipu }
    private var enabled: Bool {
        get { provider == .zhipu ? zhipuEnabled : openAIEnabled }
        nonmutating set { if provider == .zhipu { zhipuEnabled = newValue } else { openAIEnabled = newValue } }
    }
    var body: some View {
        NavigationStack {
            Form {
                Section("选择 AI 接入方式") {
                    Picker("服务商", selection: $providerRaw) {
                        ForEach(AIProvider.allCases) { Text($0.title).tag($0.rawValue) }
                    }.pickerStyle(.segmented)
                    Text("当前模型：\(provider.modelName)").font(.headline)
                    if provider == .zhipu {
                        Text("保留智谱 GLM-4.7-Flash。当前官方输入、输出免费，政策和速率限制以智谱为准。")
                            .font(.caption).foregroundStyle(.secondary)
                    } else {
                        Text("使用 OpenAI Responses API。GPT-6 Luna 按量计费；账户有可用赠送额度时按平台规则抵扣，不是永久免费模型。")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Toggle("启用当前服务商", isOn: Binding(get: { enabled }, set: { enabled = $0 }))
                        .disabled(!hasKey)
                    Text("两家的密钥分别保存；只向选中的服务商发送，不自动换模型或切换服务商。")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("\(provider.title) API Key") {
                    Text(hasKey ? "已保存这家服务商的密钥；输入新 Key 可替换。" : "还没有保存这家服务商的密钥。")
                    SecureField(provider == .openai ? "粘贴 OpenAI API Key" : "粘贴智谱模型标准 API Key", text: $newKey)
                        .textContentType(.password).textInputAutocapitalization(.never).autocorrectionDisabled()
                        .privacySensitive()
                    Button("保存并启用 \(provider.title)") {
                        do { try APIKeyStore.save(newKey, provider: provider); newKey = ""; hasKey = true; enabled = true; error = nil }
                        catch { self.error = error.localizedDescription }
                    }.disabled(newKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    if hasKey {
                        Button("删除 \(provider.title) 密钥并停用", role: .destructive) {
                            do { try APIKeyStore.delete(provider: provider); enabled = false; hasKey = false; newKey = ""; error = nil }
                            catch { self.error = error.localizedDescription }
                        }
                    }
                    if let error { Text(error).foregroundStyle(.red) }
                }
                if provider == .openai {
                    Section("创建 OpenAI Key") {
                        Link("打开 OpenAI API Keys", destination: OpenAIAccountLinks.keys)
                        Text("使用关联到赠送额度的 API 组织中的项目 Key。受限 Key 需要 Responses 写入权限；不要填智谱 Key。")
                        Link("查看 OpenAI 支持地区", destination: OpenAIAccountLinks.supportedRegions)
                    }.font(.callout)
                } else {
                    Section("创建智谱 Key") {
                        Link("打开智谱 API Keys 管理页", destination: URL(string: "https://bigmodel.cn/usercenter/proj-mgmt/apikeys")!)
                        Text("创建“模型标准 API”密钥；Coding Plan 个人、团队套餐 Key 不通用。")
                    }.font(.callout)
                }
                Section("额度与限制") {
                    Text("App 不读取账户余额或预测到账时间。服务商返回额度不足或用量限制时，对话内会显示提示并暂停发送，失败的文字会保留。普通限流会显示等待时间。")
                }.font(.callout)
                Section("发送与保存") {
                    Text("点击发送，或开启自动发送后说完，识别出的文字会通过 HTTPS 发给当前选择的 \(provider.title)。不上传录音；对话模式附带当前会话最近 6 轮文字。切换服务商会清空本次对话上下文。")
                    Text("密钥分别存入本设备的系统钥匙串，不写入代码、UserDefaults 或对话记录。关闭或删除一家不会删除另一家的密钥。")
                    if provider == .openai {
                        Text("OpenAI 请求设置 store=false，不依赖服务端对话存储；平台的数据处理仍以其政策为准。App 不自动读取账单、不修改充值设置。")
                    }
                    Text("当前为家庭自用的自带密钥模式。AI 可能误译或误判语法；文字纠错不等于发音评测。")
                }.font(.callout)
            }.foregroundStyle(Crayon.ink).tint(Crayon.green).preferredColorScheme(.light)
                .navigationTitle("AI 设置")
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } } }
                .onAppear(perform: refreshKeyState)
                .onChange(of: providerRaw) { _ in newKey = ""; error = nil; refreshKeyState() }
                .onDisappear { newKey = "" }
        }
    }
    private func refreshKeyState() {
        do { hasKey = try APIKeyStore.read(provider: provider) != nil; if !hasKey { enabled = false } }
        catch { hasKey = false; self.error = error.localizedDescription; enabled = false }
    }
}
