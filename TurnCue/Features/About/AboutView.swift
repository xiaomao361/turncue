import CoreLocation
import SwiftUI

struct AboutView: View {
    let locationService: LocationService
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @State private var showsSettingsFailure = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        BrandLogoView()
                        Text("只在需要时，告诉你下一步。")
                            .foregroundStyle(TurnCueTheme.secondaryInk)
                        Text("版本 \(AppInformation.version) · 原型")
                            .font(.footnote)
                            .foregroundStyle(TurnCueTheme.secondaryInk)
                    }
                    .padding(.vertical, 8)
                }
                .listRowBackground(TurnCueTheme.surface)

                Section("了解拐弯") {
                    ForEach(HelpPage.allCases) { page in
                        NavigationLink(value: page) {
                            Label(page.title, systemImage: page.symbol)
                                .padding(.vertical, 4)
                        }
                    }
                }
                .listRowBackground(TurnCueTheme.surface)

                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("定位权限")
                        Text(locationPermissionText)
                            .font(.subheadline)
                            .foregroundStyle(TurnCueTheme.secondaryInk)
                    }
                    Button("打开系统定位设置", systemImage: "gearshape") {
                        guard let url = URL(string: UIApplication.openSettingsURLString) else {
                            showsSettingsFailure = true
                            return
                        }
                        openURL(url) { accepted in
                            if !accepted { showsSettingsFailure = true }
                        }
                    }
                    .frame(minHeight: 44)
                } header: {
                    Text("权限")
                } footer: {
                    Text("用于附近搜索、路线生成与前台跟随。进入系统设置后选择“位置”；当前不提供后台持续导航。")
                }
                .listRowBackground(TurnCueTheme.surface)

                Section("联系开发者") {
                    SupportContactView()
                    Link(destination: AppInformation.repository) {
                        Label("GitHub 项目（联网）", systemImage: "arrow.up.right.square")
                    }
                    if AppInformation.websiteIsPublished {
                        Link("访问产品官网（联网）", destination: AppInformation.website)
                    }
                }
                .listRowBackground(TurnCueTheme.surface)
            }
            .scrollContentBackground(.hidden)
            .background(TurnCueTheme.background)
            .foregroundStyle(TurnCueTheme.ink)
            .navigationTitle("关于与帮助")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
            .navigationDestination(for: HelpPage.self) { page in
                HelpDetailView(page: page)
            }
        }
        .tint(TurnCueTheme.accent)
        .task { locationService.refreshAuthorizationStatus() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { locationService.refreshAuthorizationStatus() }
        }
        .alert("无法打开系统设置", isPresented: $showsSettingsFailure) {
            Button("知道了", role: .cancel) { }
        } message: {
            Text("请手动前往系统设置中的“隐私与安全性 → 定位服务 → 拐弯”。")
        }
    }

    private var locationPermissionText: String {
        switch locationService.authorizationStatus {
        case .notDetermined: "尚未请求，查找目的地时会询问"
        case .restricted: "受系统限制"
        case .denied: "未允许，请在系统设置中调整"
        case .authorizedWhenInUse: "使用 App 期间允许"
        case .authorizedAlways: "始终允许；拐弯仅用于前台功能"
        @unknown default: "请在系统设置中查看"
        }
    }
}

#Preview {
    AboutView(locationService: LocationService())
}
