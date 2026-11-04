import CoreLocation
import Foundation

nonisolated final class CoreLocationAircraftLocationSource: AircraftLocationSource, @unchecked Sendable {
    @MainActor static let shared = CoreLocationAircraftLocationSource()

    private static let recordingActivityDefaultsKey = "activeBackgroundLocationRecording"
    private let locationManager = CLLocationManager()
    @MainActor private var serviceSession: CLServiceSession?
    @MainActor private var backgroundActivitySession: CLBackgroundActivitySession?

    func updates() -> AsyncThrowingStream<LocationSourceEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let authorization = await authorizationEvent()
                    continuation.yield(.authorization(authorization))
                    for try await update in CLLocationUpdate.liveUpdates(.airborne) {
                        if Task.isCancelled { break }
                        if update.authorizationDeniedGlobally {
                            continuation.yield(.servicesDisabled)
                        } else if update.authorizationDenied {
                            let authorization = await authorizationEvent()
                            continuation.yield(.authorization(authorization))
                        } else if let location = update.location {
                            continuation.yield(
                                .sample(Self.sample(from: location), receivedAt: .now)
                            )
                        } else {
                            continuation.yield(.signalLost)
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    func requestWhenInUseAuthorization() async {
        await MainActor.run {
            locationManager.requestWhenInUseAuthorization()
        }
    }

    func beginRecordingActivity() async {
        await MainActor.run {
            UserDefaults.standard.set(true, forKey: Self.recordingActivityDefaultsKey)
            serviceSession = CLServiceSession(authorization: .whenInUse)
            backgroundActivitySession = CLBackgroundActivitySession()
        }
    }

    func endRecordingActivity() async {
        await MainActor.run {
            UserDefaults.standard.set(false, forKey: Self.recordingActivityDefaultsKey)
            backgroundActivitySession?.invalidate()
            serviceSession?.invalidate()
            backgroundActivitySession = nil
            serviceSession = nil
        }
    }

    @MainActor
    func resumeBackgroundActivityIfNeeded() {
        guard UserDefaults.standard.bool(forKey: Self.recordingActivityDefaultsKey) else { return }
        serviceSession = CLServiceSession(authorization: .whenInUse)
        backgroundActivitySession = CLBackgroundActivitySession()
    }

    private func authorizationEvent() async -> LocationAuthorization {
        await MainActor.run {
            switch locationManager.authorizationStatus {
            case .notDetermined: .notDetermined
            case .restricted: .restricted
            case .denied: .denied
            case .authorizedAlways, .authorizedWhenInUse, .authorized: .whenInUse
            @unknown default: .denied
            }
        }
    }

    private static func sample(from location: CLLocation) -> AircraftLocationSample {
        AircraftLocationSample(
            coordinate: WGS84Coordinate(
                latitudeDegrees: location.coordinate.latitude,
                longitudeDegrees: location.coordinate.longitude
            ),
            observedAt: location.timestamp,
            horizontalAccuracyMeters: location.horizontalAccuracy,
            altitudeMeters: location.verticalAccuracy >= 0 ? location.altitude : nil,
            verticalAccuracyMeters: location.verticalAccuracy >= 0 ? location.verticalAccuracy : nil,
            trueCourseDegrees: location.course >= 0 ? location.course : nil,
            courseAccuracyDegrees: location.courseAccuracy >= 0 ? location.courseAccuracy : nil,
            groundSpeedMetersPerSecond: location.speed >= 0 ? location.speed : nil,
            speedAccuracyMetersPerSecond: location.speedAccuracy >= 0 ? location.speedAccuracy : nil
        )
    }
}
