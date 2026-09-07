import Foundation

struct RawRouteStep: Hashable, Sendable {
    let instruction: String
    let distanceMeters: Int
    let start: GeoPoint
    let end: GeoPoint
    let action: RouteAction
}

struct RouteLegDraft: Hashable, Sendable {
    let direction: CompassDirection
    let corridor: String?
    let distanceMeters: Int
    let action: RouteAction
    let decision: String
    let trigger: GeoPoint
}

enum RouteSketchReducer {
    static func reduce(steps: [RawRouteStep], totalDistanceMeters: Int) -> [RouteLegDraft] {
        guard let first = steps.first, let last = steps.last else { return [] }
        guard steps.count > 1 else {
            return [arrivalDraft(from: first.start, to: last.end, distance: totalDistanceMeters)]
        }

        let cumulative = cumulativeDistances(for: steps)
        let minimumSpacing = max(120, min(3_000, totalDistanceMeters / 14))
        var candidates: [Candidate] = []
        for index in 1..<steps.count {
            let candidateScore = score(
                step: steps[index],
                approach: steps[index - 1],
                totalDistance: totalDistanceMeters
            )
            if candidateScore >= 2 {
                candidates.append(Candidate(index: index, position: cumulative[index], score: candidateScore))
            }
        }
        candidates.sort {
            $0.score == $1.score ? $0.position < $1.position : $0.score > $1.score
        }

        var selected: [Candidate] = []
        for candidate in candidates {
            guard selected.count < 6 else { break }
            let separated = selected.allSatisfy { abs($0.position - candidate.position) >= minimumSpacing }
            let awayFromEnds = candidate.position >= minimumSpacing / 2 && totalDistanceMeters - candidate.position >= minimumSpacing / 2
            if separated && awayFromEnds { selected.append(candidate) }
        }
        if selected.isEmpty, let fallback = candidates.first { selected = [fallback] }
        selected.sort { $0.index < $1.index }

        var drafts: [RouteLegDraft] = []
        var previousPoint = first.start
        var previousPosition = 0
        var previousStepIndex = 0
        for candidate in selected {
            let step = steps[candidate.index]
            drafts.append(RouteLegDraft(
                direction: CompassDirection.from(bearing: GeoMath.bearing(from: previousPoint, to: step.start)),
                corridor: corridor(in: steps[previousStepIndex..<candidate.index]),
                distanceMeters: max(1, candidate.position - previousPosition),
                action: step.action,
                decision: step.instruction,
                trigger: step.start
            ))
            previousPoint = step.start
            previousPosition = candidate.position
            previousStepIndex = candidate.index
        }

        drafts.append(RouteLegDraft(
            direction: CompassDirection.from(bearing: GeoMath.bearing(from: previousPoint, to: last.end)),
            corridor: corridor(in: steps[previousStepIndex..<steps.endIndex]),
            distanceMeters: max(1, totalDistanceMeters - previousPosition),
            action: .arrive,
            decision: "到达目的地",
            trigger: last.end
        ))
        return drafts
    }

    private struct Candidate { let index: Int; let position: Int; let score: Int }

    private static func cumulativeDistances(for steps: [RawRouteStep]) -> [Int] {
        var result = Array(repeating: 0, count: steps.count)
        for index in 1..<steps.count { result[index] = result[index - 1] + steps[index - 1].distanceMeters }
        return result
    }

    private static func score(step: RawRouteStep, approach: RawRouteStep, totalDistance: Int) -> Int {
        var value = 0
        if step.action == .turnLeft || step.action == .turnRight { value += 3 }
        if containsMajorFeature(step.instruction) || containsMajorFeature(approach.instruction) { value += 4 }
        if max(step.distanceMeters, approach.distanceMeters) >= max(400, totalDistance / 8) { value += 3 }
        if step.instruction.count >= 8 { value += 1 }
        return value
    }

    private static func corridor(in steps: ArraySlice<RawRouteStep>) -> String? {
        steps.filter { !$0.instruction.isEmpty }.max { $0.distanceMeters < $1.distanceMeters }?.instruction
    }

    private static func containsMajorFeature(_ text: String) -> Bool {
        ["桥", "环", "高速", "快速路", "隧道", "大道", "大街", "国道", "省道", "立交", "路口", "bridge", "highway", "expressway", "tunnel", "avenue", "interchange"]
            .contains { text.localizedCaseInsensitiveContains($0) }
    }

    private static func arrivalDraft(from: GeoPoint, to: GeoPoint, distance: Int) -> RouteLegDraft {
        RouteLegDraft(direction: CompassDirection.from(bearing: GeoMath.bearing(from: from, to: to)), corridor: nil, distanceMeters: max(1, distance), action: .arrive, decision: "到达目的地", trigger: to)
    }
}
