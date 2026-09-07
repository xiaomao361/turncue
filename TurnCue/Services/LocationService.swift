import CoreLocation
import Foundation
import Observation

enum LocationServiceError: LocalizedError {
    case requestAlreadyRunning
    case permissionDenied
    case locationUnavailable

    var errorDescription: String? {
        switch self {
        case .requestAlreadyRunning:
            "正在获取位置，请稍候。"
        case .permissionDenied:
            "无法读取当前位置。请在系统设置中允许“拐弯”使用位置。"
        case .locationUnavailable:
            "暂时无法确定当前位置。请到开阔处后重试。"
        }
    }
}

@MainActor
@Observable
final class LocationService: NSObject, CLLocationManagerDelegate {
    private let manager: CLLocationManager
    private var timeoutTask: Task<Void, Never>?
    private var continuation: CheckedContinuation<CLLocation, any Error>?

    private(set) var latestLocation: CLLocation?
    private(set) var locationRevision = 0
    private(set) var authorizationStatus: CLAuthorizationStatus

    override init() {
        let manager = CLLocationManager()
        self.manager = manager
        authorizationStatus = manager.authorizationStatus
        super.init()

        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 8
        manager.activityType = .fitness
        manager.pausesLocationUpdatesAutomatically = true
    }

    func currentLocation() async throws -> CLLocation {
        try Task.checkCancellation()
        authorizationStatus = manager.authorizationStatus
        guard authorizationStatus != .denied && authorizationStatus != .restricted else {
            throw LocationServiceError.permissionDenied
        }
        if let latestLocation,
           latestLocation.horizontalAccuracy >= 0,
           latestLocation.horizontalAccuracy <= 100,
           latestLocation.timestamp.timeIntervalSinceNow > -60 {
            return latestLocation
        }

        guard continuation == nil else {
            throw LocationServiceError.requestAlreadyRunning
        }

        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            requestPermissionOrLocation()
        }
    }

    func refreshAuthorizationStatus() {
        authorizationStatus = manager.authorizationStatus
    }

    func startNavigationUpdates() {
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            return
        }
        manager.startUpdatingLocation()
    }

    func stopNavigationUpdates() {
        manager.stopUpdatingLocation()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus

        switch authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            if continuation != nil {
                requestLocationWithTimeout()
            }
        case .denied, .restricted:
            finish(with: .failure(LocationServiceError.permissionDenied))
        case .notDetermined:
            break
        @unknown default:
            finish(with: .failure(LocationServiceError.locationUnavailable))
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last, location.horizontalAccuracy >= 0,
              location.timestamp.timeIntervalSinceNow > -60 else { return }
        latestLocation = location
        locationRevision += 1
        finish(with: .success(location))
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: any Error) {
        finish(with: .failure(error))
    }

    private func requestPermissionOrLocation() {
        authorizationStatus = manager.authorizationStatus

        switch authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            requestLocationWithTimeout()
        case .denied, .restricted:
            finish(with: .failure(LocationServiceError.permissionDenied))
        @unknown default:
            finish(with: .failure(LocationServiceError.locationUnavailable))
        }
    }

    func cancelCurrentRequest() {
        finish(with: .failure(CancellationError()))
    }

    private func requestLocationWithTimeout() {
        timeoutTask?.cancel()
        timeoutTask = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(15)) } catch { return }
            self?.finish(with: .failure(LocationServiceError.locationUnavailable))
        }
        manager.requestLocation()
    }

    private func finish(with result: Result<CLLocation, any Error>) {
        guard let continuation else { return }
        self.continuation = nil
        timeoutTask?.cancel()
        timeoutTask = nil
        continuation.resume(with: result)
    }
}
