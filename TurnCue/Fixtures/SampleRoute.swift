import Foundation

extension RouteSketch {
    static let sample = RouteSketch(
        id: UUID(uuidString: "10000000-0000-0000-0000-000000000000")!,
        source: GeoPoint(latitude: 39.899, longitude: 116.325),
        destination: PlaceReference(name: "次渠锦园北区", address: "北京市通州区次渠", coordinate: GeoPoint(latitude: 39.802, longitude: 116.598)),
        transportMode: .automobile,
        totalDistanceMeters: 27_400,
        durationMinutes: 42,
        legs: [
            RouteLeg(id: UUID(uuidString: "10000000-0000-0000-0000-000000000001")!, direction: .south, corridor: "西二环", approximateDistanceMeters: 3_500, landmark: LandmarkAnchor(name: "北京南站", coordinate: GeoPoint(latitude: 39.865, longitude: 116.379), confidence: .high), action: .turnLeft, decision: "经过北京南站后向左，进入南二环", trigger: GeoPoint(latitude: 39.868, longitude: 116.376)),
            RouteLeg(id: UUID(uuidString: "10000000-0000-0000-0000-000000000002")!, direction: .east, corridor: "南二环", approximateDistanceMeters: 8_000, landmark: LandmarkAnchor(name: "龙潭公园", coordinate: GeoPoint(latitude: 39.878, longitude: 116.440), confidence: .high), action: .continueForward, decision: "保持向东，经过龙潭公园", trigger: GeoPoint(latitude: 39.878, longitude: 116.444)),
            RouteLeg(id: UUID(uuidString: "10000000-0000-0000-0000-000000000003")!, direction: .southeast, corridor: "京沪高速方向", approximateDistanceMeters: 9_000, landmark: LandmarkAnchor(name: "十八里店桥", coordinate: GeoPoint(latitude: 39.833, longitude: 116.481), confidence: .high), action: .turnRight, decision: "到十八里店桥后向右，转向东南", trigger: GeoPoint(latitude: 39.833, longitude: 116.481)),
            RouteLeg(id: UUID(uuidString: "10000000-0000-0000-0000-000000000004")!, direction: .east, corridor: "次渠方向", approximateDistanceMeters: 5_500, landmark: LandmarkAnchor(name: "亦庄文化园", coordinate: GeoPoint(latitude: 39.806, longitude: 116.518), confidence: .medium), action: .turnLeft, decision: "接近次渠城区时向左，进入社区道路", trigger: GeoPoint(latitude: 39.805, longitude: 116.561)),
            RouteLeg(id: UUID(uuidString: "10000000-0000-0000-0000-000000000005")!, direction: .east, corridor: nil, approximateDistanceMeters: 1_400, action: .arrive, decision: "到达次渠锦园北区", trigger: GeoPoint(latitude: 39.802, longitude: 116.598))
        ]
    )
}
