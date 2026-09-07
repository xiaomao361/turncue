import SwiftUI

struct AtlasPaperBackground: View {
    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(TurnCueTheme.background))

            var grid = Path()
            stride(from: CGFloat(18), through: size.width, by: 72).forEach { x in
                grid.move(to: CGPoint(x: x, y: 0))
                grid.addLine(to: CGPoint(x: x, y: size.height))
            }
            stride(from: CGFloat(34), through: size.height, by: 86).forEach { y in
                grid.move(to: CGPoint(x: 0, y: y))
                grid.addLine(to: CGPoint(x: size.width, y: y))
            }
            context.stroke(grid, with: .color(TurnCueTheme.paperGrid), lineWidth: 1)

            var water = Path()
            water.move(to: CGPoint(x: -24, y: size.height * 0.72))
            water.addCurve(
                to: CGPoint(x: size.width + 24, y: size.height * 0.60),
                control1: CGPoint(x: size.width * 0.30, y: size.height * 0.61),
                control2: CGPoint(x: size.width * 0.62, y: size.height * 0.75)
            )
            context.stroke(water, with: .color(TurnCueTheme.paperWater), lineWidth: 9)
        }
        .accessibilityHidden(true)
        .ignoresSafeArea()
    }
}
