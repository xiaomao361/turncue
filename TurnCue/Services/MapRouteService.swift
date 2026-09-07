import CoreLocation
import Foundation
import MapKit

struct DestinationCandidate: Identifiable, Hashable, Sendable {
    let id: UUID
    let place: PlaceReference
    let distanceMeters: Int
    let direction: CompassDirection

    init(id: UUID = UUID(), place: PlaceReference, distanceMeters: Int, direction: CompassDirection) {
        self.id = id
        self.place = place
        self.distanceMeters = distanceMeters
        self.direction = direction
    }

    var distanceText: String {
        distanceMeters < 1_000
            ? "约 \(max(50, Int((Double(distanceMeters) / 50).rounded()) * 50)) 米"
            : "约 \((Double(distanceMeters) / 1_000).formatted(.number.precision(.fractionLength(1)))) 公里"
    }
}

enum MapRouteServiceError: LocalizedError {
    case noDestination
    case noRoute

    var errorDescription: String? {
        switch self {
        case .noDestination: "没有找到合适的地点。请补充城区、道路或建筑名称后重试。"
        case .noRoute: "暂时无法生成这条路线。请更换出行方式或目的地后重试。"
        }
    }
}

@MainActor
struct MapRouteService {
    func search(query: String, near location: CLLocation, radiusMeters: Double = 30_000) async throws -> [DestinationCandidate] {
        let request = MKLocalSearch.Request(naturalLanguageQuery: query, region: MKCoordinateRegion(center: location.coordinate, latitudinalMeters: radiusMeters, longitudinalMeters: radiusMeters))
        request.resultTypes = [.address, .pointOfInterest]
        let response = try await MKLocalSearch(request: request).start()
        try Task.checkCancellation()
        let source = GeoPoint(location.coordinate)
        let candidates = response.mapItems.compactMap { item -> DestinationCandidate? in
            guard let name = item.name else { return nil }
            let coordinate = GeoPoint(item.placemark.coordinate)
            return DestinationCandidate(
                place: PlaceReference(name: name, address: item.placemark.title ?? "地址暂不可用", coordinate: coordinate),
                distanceMeters: Int(GeoMath.distanceMeters(from: source, to: coordinate).rounded()),
                direction: .from(bearing: GeoMath.bearing(from: source, to: coordinate))
            )
        }.sorted { $0.distanceMeters < $1.distanceMeters }
        guard !candidates.isEmpty else { throw MapRouteServiceError.noDestination }
        return Array(candidates.prefix(8))
    }

    func route(from location: CLLocation, to destination: PlaceReference, mode: TransportMode) async throws -> RouteSketch {
        let request = MKDirections.Request()
        request.source = mapItem(name: "当前位置", point: GeoPoint(location.coordinate))
        request.destination = mapItem(name: destination.name, point: destination.coordinate)
        request.transportType = mode.mapKitTransportType
        request.requestsAlternateRoutes = false

        let response = try await MKDirections(request: request).calculate()
        try Task.checkCancellation()
        guard let route = response.routes.first else { throw MapRouteServiceError.noRoute }
        let rawSteps = route.steps.compactMap(makeRawStep)
        let drafts = RouteSketchReducer.reduce(steps: rawSteps, totalDistanceMeters: Int(route.distance.rounded()))
        guard !drafts.isEmpty else { throw MapRouteServiceError.noRoute }

        var legs: [RouteLeg] = []
        for draft in drafts {
            try Task.checkCancellation()
            let anchor = draft.action == .arrive ? nil : await landmark(near: draft.trigger)
            legs.append(RouteLeg(
                direction: draft.direction,
                corridor: cleanedCorridor(draft.corridor),
                approximateDistanceMeters: draft.distanceMeters,
                landmark: anchor,
                action: draft.action,
                decision: draft.action == .arrive ? "到达 \(destination.name)" : cleanedDecision(draft.decision),
                trigger: draft.trigger
            ))
        }
        try Task.checkCancellation()
        return RouteSketch(
            source: GeoPoint(location.coordinate),
            destination: destination,
            transportMode: mode,
            totalDistanceMeters: Int(route.distance.rounded()),
            durationMinutes: max(1, Int((route.expectedTravelTime / 60).rounded())),
            legs: legs,
            path: route.polyline.allCoordinates.map(GeoPoint.init)
        )
    }

    private func makeRawStep(_ step: MKRoute.Step) -> RawRouteStep? {
        let instruction = step.instructions.trimmingCharacters(in: .whitespacesAndNewlines)
        guard step.distance > 1, !instruction.isEmpty, let start = step.polyline.firstCoordinate, let end = step.polyline.lastCoordinate else { return nil }
        return RawRouteStep(instruction: instruction, distanceMeters: Int(step.distance.rounded()), start: GeoPoint(start), end: GeoPoint(end), action: action(for: instruction))
    }

    private func landmark(near point: GeoPoint) async -> LandmarkAnchor? {
        let request = MKLocalPointsOfInterestRequest(center: point.coordinate, radius: 260)
        guard let response = try? await MKLocalSearch(request: request).start() else { return nil }
        let named = response.mapItems.compactMap { item -> (String, GeoPoint, Double, Bool)? in
            guard let name = item.name, !name.isEmpty else { return nil }
            let coordinate = GeoPoint(item.placemark.coordinate)
            let distance = GeoMath.distanceMeters(from: point, to: coordinate)
            let stable = ["站", "桥", "公园", "医院", "大学", "学校", "商场", "广场", "中心", "馆", "tower", "station", "park", "hospital", "university", "mall", "plaza", "museum"].contains { name.localizedCaseInsensitiveContains($0) }
            return (name, coordinate, distance, stable)
        }.filter { $0.2 <= 220 }.sorted { left, right in left.3 == right.3 ? left.2 < right.2 : left.3 && !right.3 }
        guard let best = named.first, best.3 || best.2 <= 100 else { return nil }
        return LandmarkAnchor(name: best.0, coordinate: best.1, confidence: best.3 ? .high : .medium)
    }

    private func action(for instruction: String) -> RouteAction {
        let normalized = instruction.lowercased()
        if normalized.contains("右") || normalized.contains("right") { return .turnRight }
        if normalized.contains("左") || normalized.contains("left") { return .turnLeft }
        if normalized.contains("到达") || normalized.contains("arrive") || normalized.contains("destination") { return .arrive }
        return .continueForward
    }

    private func cleanedCorridor(_ text: String?) -> String? {
        guard let text else { return nil }
        let result = text
            .replacingOccurrences(of: "继续", with: "")
            .replacingOccurrences(of: "直行", with: "")
            .replacingOccurrences(of: "向左转", with: "")
            .replacingOccurrences(of: "向右转", with: "")
            .replacingOccurrences(of: "左转", with: "")
            .replacingOccurrences(of: "右转", with: "")
            .replacingOccurrences(of: "进入", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
        return result.isEmpty ? nil : result
    }

    private func cleanedDecision(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
    }

    private func mapItem(name: String, point: GeoPoint) -> MKMapItem {
        let item = MKMapItem(placemark: MKPlacemark(coordinate: point.coordinate))
        item.name = name
        return item
    }
}

extension TransportMode {
    var mapKitTransportType: MKDirectionsTransportType {
        switch self { case .walking: .walking; case .automobile: .automobile; case .cycling: .cycling }
    }
    var mapKitLaunchMode: String {
        switch self { case .walking: MKLaunchOptionsDirectionsModeWalking; case .automobile: MKLaunchOptionsDirectionsModeDriving; case .cycling: MKLaunchOptionsDirectionsModeCycling }
    }
}

extension GeoPoint {
    init(_ coordinate: CLLocationCoordinate2D) { self.init(latitude: coordinate.latitude, longitude: coordinate.longitude) }
    var coordinate: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: latitude, longitude: longitude) }
}

private extension MKPolyline {
    var allCoordinates: [CLLocationCoordinate2D] {
        guard pointCount > 0 else { return [] }
        var coordinates = Array(repeating: CLLocationCoordinate2D(), count: pointCount)
        coordinates.withUnsafeMutableBufferPointer { buffer in
            guard let baseAddress = buffer.baseAddress else { return }
            getCoordinates(baseAddress, range: NSRange(location: 0, length: pointCount))
        }
        return coordinates
    }

    var firstCoordinate: CLLocationCoordinate2D? {
        guard pointCount > 0 else { return nil }
        var coordinate = CLLocationCoordinate2D()
        getCoordinates(&coordinate, range: NSRange(location: 0, length: 1))
        return coordinate
    }
    var lastCoordinate: CLLocationCoordinate2D? {
        guard pointCount > 0 else { return nil }
        var coordinate = CLLocationCoordinate2D()
        getCoordinates(&coordinate, range: NSRange(location: pointCount - 1, length: 1))
        return coordinate
    }
}
