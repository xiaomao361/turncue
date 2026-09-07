import Foundation

struct RouteProgress: Equatable, Sendable {
    let route: RouteSketch
    private(set) var currentIndex = 0
    private(set) var isComplete = false

    var currentLeg: RouteLeg { route.legs[currentIndex] }
    var isAtDestination: Bool { isComplete }
    var isOnFinalLeg: Bool { currentIndex == route.legs.count - 1 }
    var canGoBack: Bool { currentIndex > 0 || isComplete }
    var progress: Double { isComplete ? 1 : Double(currentIndex) / Double(route.legs.count) }

    mutating func advance() {
        guard !isComplete else { return }
        if isOnFinalLeg { isComplete = true } else { currentIndex += 1 }
    }

    /// Ignore confirmations for a browsed node or a node already advanced by location.
    @discardableResult
    mutating func confirmArrival(at nodeID: UUID?) -> Bool {
        guard nodeID == currentLeg.id, !isComplete else { return false }
        advance()
        return true
    }

    mutating func goBack() {
        if isComplete { isComplete = false } else { currentIndex = max(0, currentIndex - 1) }
    }

    mutating func restart() { currentIndex = 0; isComplete = false }

    @discardableResult
    mutating func updateLocation(latitude: Double, longitude: Double, horizontalAccuracy: Double) -> Bool {
        guard horizontalAccuracy >= 0, horizontalAccuracy <= 80 else { return false }
        let distance = GeoMath.distanceMeters(
            from: GeoPoint(latitude: latitude, longitude: longitude),
            to: currentLeg.trigger
        )
        // The final arrival is explicitly confirmed; proximity alone is not proof of arrival.
        guard distance <= 80, !isOnFinalLeg, !isComplete else { return false }
        advance()
        return true
    }
}

enum GeoMath {
    static func distanceMeters(from: GeoPoint, to: GeoPoint) -> Double {
        let earthRadius = 6_371_000.0
        let latitudeDelta = radians(to.latitude - from.latitude)
        let longitudeDelta = radians(to.longitude - from.longitude)
        let startLatitude = radians(from.latitude)
        let endLatitude = radians(to.latitude)
        let a = sin(latitudeDelta / 2) * sin(latitudeDelta / 2)
            + cos(startLatitude) * cos(endLatitude) * sin(longitudeDelta / 2) * sin(longitudeDelta / 2)
        return earthRadius * 2 * atan2(sqrt(a), sqrt(1 - a))
    }

    static func bearing(from: GeoPoint, to: GeoPoint) -> Double {
        let startLatitude = radians(from.latitude)
        let endLatitude = radians(to.latitude)
        let longitudeDelta = radians(to.longitude - from.longitude)
        let y = sin(longitudeDelta) * cos(endLatitude)
        let x = cos(startLatitude) * sin(endLatitude) - sin(startLatitude) * cos(endLatitude) * cos(longitudeDelta)
        return atan2(y, x) * 180 / .pi
    }

    private static func radians(_ degrees: Double) -> Double { degrees * .pi / 180 }
}
