import SwiftUI

enum TurnCueTheme {
    static let background = Color(red: 0.95, green: 0.92, blue: 0.83)
    static let surface = Color(red: 0.98, green: 0.96, blue: 0.89)
    static let paperDeep = Color(red: 0.88, green: 0.83, blue: 0.70)
    static let paperGrid = Color(red: 0.42, green: 0.45, blue: 0.39).opacity(0.13)
    static let paperWater = Color(red: 0.47, green: 0.61, blue: 0.60).opacity(0.16)
    static let ink = Color(red: 0.07, green: 0.10, blue: 0.10)
    static let secondaryInk = Color(red: 0.34, green: 0.32, blue: 0.27)
    static let accent = Color(red: 0.80, green: 0.15, blue: 0.07)
    static let routeHalo = Color(red: 0.98, green: 0.94, blue: 0.82)
    static let connector = Color.black.opacity(0.2)

    static func atlasTitle(_ size: CGFloat) -> Font {
        .custom("Songti SC", size: size, relativeTo: .title)
            .weight(.bold)
    }
}
