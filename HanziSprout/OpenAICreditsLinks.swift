import SwiftUI

struct OpenAICreditsLinks: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("OpenAI 可查询额度", systemImage: "creditcard").font(.headline)
            Link("查询剩余额度与到期时间 ↗", destination: OpenAIAccountLinks.billing)
            Link("查看 API 用量 ↗", destination: OpenAIAccountLinks.usage)
            Link("查看 Pro 赠送额度／关联组织 ↗", destination: OpenAIAccountLinks.subscription)
            Text("打开官网并登录，确认与当前 Key 对应的 API 组织。App 不自动读取账户余额，也不会把用量或报错推算成剩余美元金额。")
                .font(.caption).foregroundStyle(Crayon.ink.opacity(0.85))
            Text("OpenAI API 按量计费；赠送额度的实际金额、有效期和抵扣规则以账户页面为准。额度用完后的行为取决于账户购买余额和充值设置。")
                .font(.caption).foregroundStyle(Crayon.ink.opacity(0.85))
        }.foregroundStyle(Crayon.ink).tint(Crayon.green)
    }
}
