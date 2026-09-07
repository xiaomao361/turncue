import SwiftUI

struct HelpDetailView: View {
    let page: HelpPage

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                Text(page.introduction)
                    .font(.title3)
                    .foregroundStyle(TurnCueTheme.secondaryInk)
                ForEach(page.sections) { section in
                    VStack(alignment: .leading, spacing: 10) {
                        Text(section.title)
                            .font(.title3.bold())
                            .accessibilityAddTraits(.isHeader)
                        Text(section.text)
                            .font(.body)
                            .lineSpacing(5)
                            .textSelection(.enabled)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                if page == .privacy {
                    VStack(alignment: .leading, spacing: 12) {
                        Link("Apple 地图与隐私（联网）", destination: AppInformation.appleMapsPrivacy)
                            .frame(minHeight: 44)
                        Link("GitHub 隐私声明（联网）", destination: AppInformation.githubPrivacy)
                            .frame(minHeight: 44)
                    }
                }
                if page == .support || page == .privacy {
                    Divider()
                    SupportContactView()
                }
            }
            .padding(20)
        }
        .background(TurnCueTheme.background)
        .foregroundStyle(TurnCueTheme.ink)
        .navigationTitle(page.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
    }
}

#Preview {
    NavigationStack { HelpDetailView(page: .privacy) }
}
