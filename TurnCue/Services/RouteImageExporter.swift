import MapKit
import SwiftUI
import UIKit

struct ExportedRouteImage: Identifiable {
    let id = UUID()
    let image: UIImage
}

struct ActivityShareView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

@MainActor
enum RouteImageExporter {
    static func render(route: RouteSketch) async throws -> UIImage {
        let mapSize = CGSize(width: 1_080, height: 700)
        let options = MKMapSnapshotter.Options()
        options.region = region(for: route)
        options.size = mapSize
        options.scale = 1
        options.traitCollection = UITraitCollection(userInterfaceStyle: .light)
        let snapshot = try await MKMapSnapshotter(options: options).start()

        let rowHeight: CGFloat = 76
        let imageHeight = 1_050 + CGFloat(route.legs.count) * rowHeight
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 1_200, height: imageHeight))
        return renderer.image { context in
            let canvas = context.cgContext
            UIColor(red: 0.95, green: 0.92, blue: 0.83, alpha: 1).setFill()
            canvas.fill(CGRect(x: 0, y: 0, width: 1_200, height: imageHeight))

            canvas.setFillColor(UIColor(red: 0.88, green: 0.16, blue: 0.08, alpha: 1).cgColor)
            canvas.fill(CGRect(x: 60, y: 42, width: 64, height: 6))
            draw(route.destination.name, in: CGRect(x: 60, y: 62, width: 1_080, height: 58), font: atlasFont(size: 44, weight: .bold), color: UIColor(red: 0.07, green: 0.10, blue: 0.10, alpha: 1))
            let summary = "\(route.totalDistanceText) · 约 \(route.durationMinutes) 分钟 · \(route.legs.count) 个关键节点 · 草图不按比例"
            draw(summary, in: CGRect(x: 60, y: 112, width: 1_080, height: 34), font: .systemFont(ofSize: 23, weight: .medium), color: .darkGray)

            let mapRect = CGRect(x: 60, y: 170, width: mapSize.width, height: mapSize.height)
            snapshot.image.draw(in: mapRect)
            canvas.saveGState()
            canvas.translateBy(x: mapRect.minX, y: mapRect.minY)
            canvas.clip(to: CGRect(origin: .zero, size: mapSize))
            drawRoute(route, snapshot: snapshot, context: canvas)
            canvas.restoreGState()

            draw("关键节点", in: CGRect(x: 60, y: 900, width: 1_080, height: 40), font: atlasFont(size: 30, weight: .bold), color: .label)
            for (index, leg) in route.legs.enumerated() {
                let y = 954 + CGFloat(index) * rowHeight
                drawLegendRow(leg: leg, sequence: index + 1, y: y, context: canvas)
            }

            if let mark = UIImage(named: "BrandMark") {
                mark.draw(in: CGRect(x: 60, y: imageHeight - 72, width: 48, height: 48))
            }
            draw("拐弯  ·  路线草图", in: CGRect(x: 124, y: imageHeight - 62, width: 400, height: 36), font: .systemFont(ofSize: 20, weight: .semibold), color: .darkGray)
        }
    }

    private static func drawRoute(_ route: RouteSketch, snapshot: MKMapSnapshotter.Snapshot, context: CGContext) {
        let points = route.displayPath.map { snapshot.point(for: $0.coordinate) }
        if let first = points.first {
            context.beginPath()
            context.move(to: first)
            for point in points.dropFirst() { context.addLine(to: point) }
            context.setStrokeColor(UIColor(red: 0.98, green: 0.94, blue: 0.82, alpha: 1).cgColor)
            context.setLineWidth(18)
            context.setLineCap(.round)
            context.setLineJoin(.round)
            context.strokePath()

            context.beginPath()
            context.move(to: first)
            for point in points.dropFirst() { context.addLine(to: point) }
            context.setStrokeColor(UIColor(red: 0.91, green: 0.31, blue: 0.16, alpha: 1).cgColor)
            context.setLineWidth(10)
            context.setLineCap(.round)
            context.setLineJoin(.round)
            context.strokePath()
        }

        drawCircle(title: "起", at: snapshot.point(for: route.source.coordinate), fill: UIColor(red: 0.07, green: 0.10, blue: 0.10, alpha: 1), context: context)
        for (index, leg) in route.legs.enumerated() {
            let point = snapshot.point(for: leg.trigger.coordinate)
            drawCircle(title: leg.action == .arrive ? "终" : "\(index + 1)", at: point, fill: leg.action == .arrive ? UIColor(red: 0.91, green: 0.31, blue: 0.16, alpha: 1) : UIColor(red: 0.08, green: 0.12, blue: 0.14, alpha: 1), context: context)
            drawMapLabel(leg.displayName, near: point, context: context)
        }
    }

    private static func drawCircle(title: String, at point: CGPoint, fill: UIColor, context: CGContext) {
        let rect = CGRect(x: point.x - 24, y: point.y - 24, width: 48, height: 48)
        context.setFillColor(UIColor.white.cgColor)
        context.fillEllipse(in: rect.insetBy(dx: -4, dy: -4))
        context.setFillColor(fill.cgColor)
        context.fillEllipse(in: rect)
        let attributes: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 18, weight: .bold), .foregroundColor: UIColor.white]
        let size = (title as NSString).size(withAttributes: attributes)
        (title as NSString).draw(at: CGPoint(x: point.x - size.width / 2, y: point.y - size.height / 2), withAttributes: attributes)
    }

    private static func drawMapLabel(_ text: String, near point: CGPoint, context: CGContext) {
        let attributes: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 17, weight: .semibold), .foregroundColor: UIColor.label]
        let measured = (text as NSString).size(withAttributes: attributes)
        let width = min(260, measured.width + 22)
        let x = min(1_080 - width - 8, max(8, point.x - width / 2))
        let y = min(700 - 42, max(8, point.y + 31))
        let rect = CGRect(x: x, y: y, width: width, height: 34)
        context.setFillColor(UIColor(red: 0.98, green: 0.96, blue: 0.89, alpha: 0.94).cgColor)
        context.fill(rect)
        (text as NSString).draw(in: rect.insetBy(dx: 11, dy: 6), withAttributes: attributes)
    }

    private static func drawLegendRow(leg: RouteLeg, sequence: Int, y: CGFloat, context: CGContext) {
        let marker = CGRect(x: 60, y: y + 4, width: 46, height: 46)
        context.setFillColor((leg.action == .arrive ? UIColor(red: 0.91, green: 0.31, blue: 0.16, alpha: 1) : UIColor(red: 0.08, green: 0.12, blue: 0.14, alpha: 1)).cgColor)
        context.fillEllipse(in: marker)
        let markerText = leg.action == .arrive ? "终" : "\(sequence)"
        draw(markerText, in: marker, font: .systemFont(ofSize: 18, weight: .bold), color: .white, alignment: .center)
        draw(leg.displayName, in: CGRect(x: 128, y: y, width: 420, height: 32), font: atlasFont(size: 23, weight: .bold), color: .label)
        draw(leg.approachSummary, in: CGRect(x: 128, y: y + 34, width: 420, height: 28), font: .systemFont(ofSize: 18, weight: .regular), color: .darkGray)
        draw("到达后：\(leg.decision)", in: CGRect(x: 570, y: y + 8, width: 570, height: 48), font: .systemFont(ofSize: 19, weight: .medium), color: .label)
    }

    private static func draw(_ text: String, in rect: CGRect, font: UIFont, color: UIColor, alignment: NSTextAlignment = .left) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment
        paragraph.lineBreakMode = .byTruncatingTail
        (text as NSString).draw(in: rect, withAttributes: [.font: font, .foregroundColor: color, .paragraphStyle: paragraph])
    }

    private static func atlasFont(size: CGFloat, weight: UIFont.Weight) -> UIFont {
        let system = UIFont.systemFont(ofSize: size, weight: weight)
        guard let descriptor = system.fontDescriptor.withDesign(.serif) else { return system }
        return UIFont(descriptor: descriptor, size: size)
    }

    private static func region(for route: RouteSketch) -> MKCoordinateRegion {
        let points = route.displayPath
        let latitudes = points.map(\.latitude)
        let longitudes = points.map(\.longitude)
        guard let minLatitude = latitudes.min(), let maxLatitude = latitudes.max(), let minLongitude = longitudes.min(), let maxLongitude = longitudes.max() else {
            return MKCoordinateRegion(center: route.source.coordinate, latitudinalMeters: 2_000, longitudinalMeters: 2_000)
        }
        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: (minLatitude + maxLatitude) / 2, longitude: (minLongitude + maxLongitude) / 2),
            span: MKCoordinateSpan(latitudeDelta: max(0.008, (maxLatitude - minLatitude) * 1.28), longitudeDelta: max(0.008, (maxLongitude - minLongitude) * 1.28))
        )
    }
}
