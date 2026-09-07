import SwiftUI

struct SupportContactView: View {
    @Environment(\.openURL) private var openURL
    @State private var showsMailFailure = false
    @State private var copiedEmail = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(AppInformation.supportEmail)
                .textSelection(.enabled)
                .foregroundStyle(TurnCueTheme.secondaryInk)
            Button("准备反馈邮件", systemImage: "envelope") {
                guard let url = AppInformation.supportMailURL else {
                    showsMailFailure = true
                    return
                }
                openURL(url) { accepted in
                    if !accepted { showsMailFailure = true }
                }
            }
            .frame(minHeight: 44)
            Button(copiedEmail ? "已复制邮箱" : "复制支持邮箱", systemImage: "doc.on.doc") {
                UIPasteboard.general.string = AppInformation.supportEmail
                copiedEmail = true
            }
            .frame(minHeight: 44)
            Text("邮件会预填 App 版本与问题模板，由你检查后发送。请不要附上私人住址或完整出行轨迹。")
                .font(.footnote)
                .foregroundStyle(TurnCueTheme.secondaryInk)
        }
        .alert("无法打开邮件 App", isPresented: $showsMailFailure) {
            Button("知道了", role: .cancel) { }
        } message: {
            Text("请复制支持邮箱，在你使用的邮件 App 中联系开发者。")
        }
    }
}
