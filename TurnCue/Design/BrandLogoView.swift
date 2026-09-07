import SwiftUI

struct BrandLogoView: View {
    var showsTagline = true

    var body: some View {
        HStack(spacing: 12) {
            Image("BrandMark")
                .resizable()
                .scaledToFit()
                .frame(width: 48, height: 48)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 1) {
                Text("拐弯")
                    .font(TurnCueTheme.atlasTitle(28))
                    .foregroundStyle(TurnCueTheme.ink)
                if showsTagline {
                    Text("TURN CUE  ·  路线草图")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .tracking(1.2)
                        .foregroundStyle(TurnCueTheme.accent)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("拐弯，路线草图")
    }
}

#Preview {
    BrandLogoView()
        .padding(24)
        .background(TurnCueTheme.background)
}
