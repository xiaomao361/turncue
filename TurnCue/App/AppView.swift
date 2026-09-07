import SwiftUI

struct AppView: View {
    @State private var path: [AppRoute] = []
    @State private var locationService = LocationService()

    var body: some View {
        NavigationStack(path: $path) {
            DestinationSearchView(locationService: locationService) { route in
                path.append(.preview(route))
            }
            .navigationDestination(for: AppRoute.self) { route in
                switch route {
                case .preview(let sketch):
                    RoutePreviewView(route: sketch, locationService: locationService)
                }
            }
        }
        .tint(TurnCueTheme.accent)
    }
}

enum AppRoute: Hashable {
    case preview(RouteSketch)
}

#Preview {
    AppView()
}
