import CoreLocation
import CoreMotion
import Foundation

@MainActor
final class CoreMotionSupplementalSensorSource: NSObject, SupplementalSensorSource, CLLocationManagerDelegate {
    static let shared = CoreMotionSupplementalSensorSource()

    private let altimeter = CMAltimeter()
    private let locationManager = CLLocationManager()
    private var continuation: AsyncThrowingStream<SupplementalSensorEvent, Error>.Continuation?

    private override init() {
        super.init()
        locationManager.delegate = self
    }

    func updates() -> AsyncThrowingStream<SupplementalSensorEvent, Error> {
        continuation?.finish()
        let (stream, continuation) = AsyncThrowingStream.makeStream(
            of: SupplementalSensorEvent.self,
            bufferingPolicy: .bufferingNewest(4)
        )
        self.continuation = continuation
        continuation.onTermination = { _ in
            Task { @MainActor in
                CoreMotionSupplementalSensorSource.shared.stop()
            }
        }

        if CMAltimeter.isRelativeAltitudeAvailable() {
            altimeter.startRelativeAltitudeUpdates(to: .main) { [weak self] data, error in
                Task { @MainActor in
                    if let error {
                        self?.continuation?.finish(throwing: error)
                    } else if let data {
                        self?.continuation?.yield(.relativeBarometricAltitude(
                            meters: data.relativeAltitude.doubleValue,
                            observedAt: Date()
                        ))
                    }
                }
            }
        }
        if CLLocationManager.headingAvailable() {
            locationManager.startUpdatingHeading()
        }
        return stream
    }

    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        let accuracy = newHeading.headingAccuracy >= 0 ? newHeading.headingAccuracy : nil
        continuation?.yield(.deviceHeading(
            degrees: newHeading.magneticHeading,
            accuracyDegrees: accuracy,
            observedAt: newHeading.timestamp
        ))
    }

    private func stop() {
        altimeter.stopRelativeAltitudeUpdates()
        locationManager.stopUpdatingHeading()
        continuation = nil
    }
}
