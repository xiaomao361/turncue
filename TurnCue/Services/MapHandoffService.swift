import MapKit

@MainActor
enum MapHandoffService {
    static func open(route: RouteSketch) {
        let source = MKMapItem(placemark: MKPlacemark(coordinate: route.source.coordinate))
        source.name = "出发点"
        let destination = MKMapItem(placemark: MKPlacemark(coordinate: route.destination.coordinate.coordinate))
        destination.name = route.destination.name
        MKMapItem.openMaps(with: [source, destination], launchOptions: [MKLaunchOptionsDirectionsModeKey: route.transportMode.mapKitLaunchMode])
    }
}
