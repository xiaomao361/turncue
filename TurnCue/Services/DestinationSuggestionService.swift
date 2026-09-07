import CoreLocation
import Foundation
import MapKit
import Observation

struct PlaceSuggestion: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let query: String
}

@MainActor
@Observable
final class DestinationSuggestionService: NSObject, MKLocalSearchCompleterDelegate {
    private let completer = MKLocalSearchCompleter()
    private(set) var suggestions: [PlaceSuggestion] = []

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
    }

    func update(query: String, near location: CLLocationCoordinate2D?) {
        if let location { completer.region = MKCoordinateRegion(center: location, latitudinalMeters: 30_000, longitudinalMeters: 30_000) }
        suggestions = []
        if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            completer.cancel()
            completer.queryFragment = ""
            return
        }
        completer.queryFragment = query
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        guard !completer.queryFragment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            suggestions = []
            return
        }
        suggestions = completer.results.prefix(4).map {
            PlaceSuggestion(id: "\($0.title)|\($0.subtitle)", title: $0.title, subtitle: $0.subtitle, query: [$0.title, $0.subtitle].filter { !$0.isEmpty }.joined(separator: " "))
        }
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: any Error) { suggestions = [] }
}
