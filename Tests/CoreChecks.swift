import Foundation

@main
enum CoreChecks {
    static func main() {
        let route = RouteSketch.sample
        precondition(route.legs.count == 5)
        precondition(route.legs.last?.action == .arrive)
        precondition(route.totalDistanceText == "约 27.5 公里")
        precondition(route.displayPath.first == route.source)
        precondition(route.displayPath.last == route.legs.last?.trigger)
        precondition(route.legs.first?.displayName == "北京南站")
        precondition(route.legs.first?.approachSummary.contains("向南") == true)

        var progress = RouteProgress(route: route)
        precondition(progress.currentIndex == 0)
        for _ in 0..<10 { progress.advance() }
        precondition(progress.currentIndex == route.legs.count - 1)
        precondition(progress.isAtDestination)
        progress.restart()
        precondition(progress.currentIndex == 0)

        let source = GeoPoint(latitude: 39.9, longitude: 116.4)
        var raw: [RawRouteStep] = []
        for index in 0..<18 {
            let instruction: String
            let action: RouteAction
            if index == 6 { instruction = "到主路口后右转进入东三环"; action = .turnRight }
            else if index == 12 { instruction = "经过大桥后左转"; action = .turnLeft }
            else { instruction = "继续直行"; action = .continueForward }
            let start = GeoPoint(latitude: source.latitude - Double(index) * 0.001, longitude: source.longitude + Double(index) * 0.001)
            let end = GeoPoint(latitude: source.latitude - Double(index + 1) * 0.001, longitude: source.longitude + Double(index + 1) * 0.001)
            raw.append(RawRouteStep(instruction: instruction, distanceMeters: index == 6 || index == 12 ? 1_200 : 80, start: start, end: end, action: action))
        }
        let reduced = RouteSketchReducer.reduce(steps: raw, totalDistanceMeters: raw.reduce(0) { $0 + $1.distanceMeters })
        precondition((2...7).contains(reduced.count))
        precondition(reduced.last?.action == .arrive)

        let proximity = RouteSketch(source: source, destination: PlaceReference(name: "终点", address: "测试", coordinate: GeoPoint(latitude: 39.91, longitude: 116.41)), transportMode: .walking, totalDistanceMeters: 200, durationMinutes: 3, legs: [
            RouteLeg(direction: .east, corridor: nil, approximateDistanceMeters: 100, action: .turnRight, decision: "右转", trigger: source),
            RouteLeg(direction: .north, corridor: nil, approximateDistanceMeters: 100, action: .arrive, decision: "到达", trigger: GeoPoint(latitude: 39.91, longitude: 116.41))
        ])
        var proximityProgress = RouteProgress(route: proximity)
        precondition(proximityProgress.updateLocation(latitude: 39.90005, longitude: 116.40005, horizontalAccuracy: 8))
        precondition(proximityProgress.currentIndex == 1)
        precondition(!proximityProgress.isComplete, "Entering the final leg must not finish the route")
        precondition(proximityProgress.progress < 1)
        precondition(!proximityProgress.updateLocation(latitude: 39.91, longitude: 116.41, horizontalAccuracy: 8), "Final arrival requires confirmation")
        precondition(!proximityProgress.isComplete)
        proximityProgress.advance()
        precondition(proximityProgress.isComplete && proximityProgress.progress == 1)
        proximityProgress.advance()
        precondition(proximityProgress.currentIndex == 1 && proximityProgress.isComplete)
        proximityProgress.goBack()
        precondition(!proximityProgress.isComplete && proximityProgress.currentIndex == 1, "Undo arrival keeps the final leg active")
        proximityProgress.goBack()
        precondition(proximityProgress.currentIndex == 0 && !proximityProgress.canGoBack)
        proximityProgress.goBack()
        precondition(proximityProgress.currentIndex == 0)
        precondition(!proximityProgress.updateLocation(latitude: source.latitude, longitude: source.longitude, horizontalAccuracy: -1))
        precondition(!proximityProgress.updateLocation(latitude: source.latitude, longitude: source.longitude, horizontalAccuracy: 81))
        precondition(!proximityProgress.updateLocation(latitude: 40.0, longitude: 117.0, horizontalAccuracy: 8))
        precondition(proximityProgress.currentIndex == 0)
        proximityProgress.advance()
        proximityProgress.advance()
        proximityProgress.restart()
        precondition(!proximityProgress.isComplete && proximityProgress.currentIndex == 0 && proximityProgress.progress == 0)

        let single = RouteSketch(source: source, destination: proximity.destination, transportMode: .walking, totalDistanceMeters: 100, durationMinutes: 2, legs: [proximity.legs[1]])
        var singleProgress = RouteProgress(route: single)
        precondition(singleProgress.isOnFinalLeg && !singleProgress.isComplete && singleProgress.progress == 0)
        singleProgress.advance()
        precondition(singleProgress.isComplete && singleProgress.progress == 1)
        singleProgress.goBack()
        precondition(!singleProgress.isComplete && singleProgress.currentIndex == 0)
        var confirmation = RouteProgress(route: route)
        precondition(!confirmation.confirmArrival(at: route.legs[2].id), "Browsing another node cannot complete the current leg")
        precondition(!confirmation.confirmArrival(at: nil))
        precondition(confirmation.currentIndex == 0)
        let firstNodeID = confirmation.currentLeg.id
        precondition(confirmation.confirmArrival(at: firstNodeID))
        precondition(!confirmation.confirmArrival(at: firstNodeID), "A delayed confirmation must not advance the next leg")
        precondition(confirmation.currentIndex == 1)
        confirmation.goBack()
        precondition(confirmation.currentIndex == 0)
        precondition(confirmation.confirmArrival(at: firstNodeID))
        while !confirmation.isComplete {
            precondition(confirmation.confirmArrival(at: confirmation.currentLeg.id))
        }
        precondition(!confirmation.confirmArrival(at: confirmation.currentLeg.id), "Arrival cannot be confirmed twice")
        print("TurnCue core checks passed: route fixtures, reducer, final-leg confirmation, completion, undo, restart, location accuracy/distance guards, single-leg route, browsed-node and stale-confirmation protection")
    }
}
