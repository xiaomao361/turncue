import Foundation

enum TransportMode: String, Codable, CaseIterable, Hashable, Sendable {
    case walking, automobile, cycling

    var title: String {
        switch self {
        case .walking: "步行"
        case .automobile: "驾车"
        case .cycling: "骑行"
        }
    }

    var symbolName: String {
        switch self {
        case .walking: "figure.walk"
        case .automobile: "car"
        case .cycling: "bicycle"
        }
    }

    static func recommended(forStraightLineDistance distance: Double) -> Self {
        distance <= 3_000 ? .walking : .automobile
    }
}

enum RouteAction: String, Codable, Hashable, Sendable {
    case continueForward, turnRight, turnLeft, arrive

    var title: String {
        switch self {
        case .continueForward: "继续前行"
        case .turnRight: "向右转"
        case .turnLeft: "向左转"
        case .arrive: "到达目的地"
        }
    }

    var symbolName: String {
        switch self {
        case .continueForward: "arrow.up"
        case .turnRight: "arrow.turn.up.right"
        case .turnLeft: "arrow.turn.up.left"
        case .arrive: "mappin.and.ellipse"
        }
    }
}

enum CompassDirection: String, Codable, Hashable, Sendable {
    case north, northeast, east, southeast, south, southwest, west, northwest

    var title: String {
        switch self {
        case .north: "向北"
        case .northeast: "向东北"
        case .east: "向东"
        case .southeast: "向东南"
        case .south: "向南"
        case .southwest: "向西南"
        case .west: "向西"
        case .northwest: "向西北"
        }
    }

    static func from(bearing: Double) -> Self {
        let normalized = (bearing + 360).truncatingRemainder(dividingBy: 360)
        return switch normalized {
        case 22.5..<67.5: .northeast
        case 67.5..<112.5: .east
        case 112.5..<157.5: .southeast
        case 157.5..<202.5: .south
        case 202.5..<247.5: .southwest
        case 247.5..<292.5: .west
        case 292.5..<337.5: .northwest
        default: .north
        }
    }
}

enum LandmarkConfidence: String, Codable, Hashable, Sendable {
    case medium, high
}

struct GeoPoint: Hashable, Codable, Sendable {
    let latitude: Double
    let longitude: Double
}

struct PlaceReference: Hashable, Codable, Sendable {
    let name: String
    let address: String
    let coordinate: GeoPoint
}

struct LandmarkAnchor: Hashable, Codable, Sendable {
    let name: String
    let coordinate: GeoPoint
    let confidence: LandmarkConfidence
}

struct RouteLeg: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    let direction: CompassDirection
    let corridor: String?
    let approximateDistanceMeters: Int
    let landmark: LandmarkAnchor?
    let action: RouteAction
    let decision: String
    let trigger: GeoPoint

    init(id: UUID = UUID(), direction: CompassDirection, corridor: String?, approximateDistanceMeters: Int, landmark: LandmarkAnchor? = nil, action: RouteAction, decision: String, trigger: GeoPoint) {
        self.id = id
        self.direction = direction
        self.corridor = corridor
        self.approximateDistanceMeters = approximateDistanceMeters
        self.landmark = landmark
        self.action = action
        self.decision = decision
        self.trigger = trigger
    }

    var approximateDistanceText: String { DistanceText.approximate(meters: approximateDistanceMeters) }

    var displayName: String {
        if let landmark { return landmark.name }
        if let corridor, !corridor.isEmpty { return corridor }
        let cleaned = decision
            .replacingOccurrences(of: "到达", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
        return cleaned.isEmpty ? action.title : cleaned
    }

    var approachSummary: String {
        var parts = [direction.title, approximateDistanceText]
        if let corridor, corridor != displayName { parts.append("沿 \(corridor)") }
        return parts.joined(separator: " · ")
    }
}

struct RouteSketch: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    let source: GeoPoint
    let destination: PlaceReference
    let transportMode: TransportMode
    let totalDistanceMeters: Int
    let durationMinutes: Int
    let legs: [RouteLeg]
    let path: [GeoPoint]

    init(id: UUID = UUID(), source: GeoPoint, destination: PlaceReference, transportMode: TransportMode, totalDistanceMeters: Int, durationMinutes: Int, legs: [RouteLeg], path: [GeoPoint] = []) {
        precondition(!legs.isEmpty, "A route sketch needs at least one leg.")
        self.id = id
        self.source = source
        self.destination = destination
        self.transportMode = transportMode
        self.totalDistanceMeters = totalDistanceMeters
        self.durationMinutes = durationMinutes
        self.legs = legs
        self.path = path
    }

    var totalDistanceText: String { DistanceText.approximate(meters: totalDistanceMeters) }

    var displayPath: [GeoPoint] {
        path.count >= 2 ? path : [source] + legs.map(\.trigger)
    }
}

private enum DistanceText {
    static func approximate(meters: Int) -> String {
        if meters < 1_000 {
            let rounded = max(50, Int((Double(meters) / 50).rounded()) * 50)
            return "约 \(rounded) 米"
        }
        let rounded = ((Double(meters) / 1_000) * 2).rounded() / 2
        if rounded.rounded() == rounded { return "约 \(Int(rounded)) 公里" }
        return "约 \(rounded.formatted(.number.precision(.fractionLength(1)))) 公里"
    }
}
