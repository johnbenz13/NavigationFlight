import Foundation
import Testing
@testable import NavigationFlight

@Suite("Position Check state")
struct PositionCheckStateTests {
    @Test("A completed hold with a usable fix starts one disclosure session")
    func completedHoldStartsDisclosure() throws {
        let sample = sample()
        let transition = PositionCheckState.idle.transition(
            .holdCompleted(availability: .ready(sample), restoration: .empty),
            now: .zero
        )

        let session = try #require(transition.state.activeSession)
        #expect(session.projection.coordinate == sample.coordinate)
        #expect(session.projection.horizontalAccuracyMeters == 35)
        #expect(session.projection.trueCourseDegrees == 72)
        #expect(session.deadline == .seconds(10))
        #expect(transition.effect == .scheduleDeadline(generation: session.generation, deadline: .seconds(10)))
    }

    @Test("A completed hold without a usable fix starts cancellable acquisition")
    func completedHoldStartsAcquisition() throws {
        let transition = PositionCheckState.idle.transition(
            .holdCompleted(availability: .acquiring, restoration: .empty),
            now: .seconds(4)
        )

        let request = try #require(transition.state.acquisitionRequest)
        #expect(request.deadline == .seconds(14))
        #expect(transition.effect == .scheduleDeadline(generation: request.generation, deadline: .seconds(14)))

        let cancelled = transition.state.transition(.cancel, now: .seconds(5))
        #expect(cancelled.state == .idle)
        #expect(cancelled.effect == .cancelDeadline)
    }

    @Test("A usable fix during acquisition starts a fresh ten second disclosure")
    func acquisitionSuccessStartsDisclosure() throws {
        let acquiring = PositionCheckState.idle.transition(
            .holdCompleted(availability: .acquiring, restoration: .empty),
            now: .zero
        ).state
        let request = try #require(acquiring.acquisitionRequest)

        let active = acquiring.transition(
            .locationAvailabilityChanged(.ready(sample())),
            now: .seconds(7)
        )

        let session = try #require(active.state.activeSession)
        #expect(session.deadline == .seconds(17))
        #expect(session.generation != request.generation)
    }

    @Test("Stale deadlines are ignored and the current generation expires exactly")
    func staleDeadlineIsIgnored() throws {
        let first = PositionCheckState.idle.transition(
            .holdCompleted(availability: .ready(sample()), restoration: .empty),
            now: .zero
        ).state
        let firstSession = try #require(first.activeSession)
        let restarted = first.transition(
            .restartHoldCompleted(availability: .ready(sample()), restoration: .empty),
            now: .seconds(3)
        ).state
        let current = try #require(restarted.activeSession)

        #expect(restarted.transition(.deadlineReached(firstSession.generation), now: .seconds(10)).state == restarted)
        #expect(restarted.transition(.deadlineReached(current.generation), now: .seconds(13)).state == .idle)
    }

    @Test("Lifecycle termination clears disclosure and restores its captured map context")
    func lifecycleTerminationRestoresMap() throws {
        let restoration = CockpitRestoration(
            camera: AviationMapCameraState(
                center: AviationMapCoordinate(latitude: 32.1, longitude: 34.8),
                zoomLevel: 9,
                direction: 17,
                pitch: 2
            ),
            isCameraUserControlled: true,
            selectedCallout: nil,
            focusRequest: AviationMapFocusRequest(mode: .overview)
        )
        let active = PositionCheckState.idle.transition(
            .holdCompleted(availability: .ready(sample()), restoration: restoration),
            now: .zero
        ).state

        let ended = active.transition(.sceneBecameInactive, now: .seconds(2))

        #expect(ended.state == .idle)
        #expect(ended.effect == .endDisclosure(restoration: restoration))
    }

    @Test("Signal loss clears disclosure and restores map context before explaining the loss")
    func signalLossFailsClosed() throws {
        let restoration = CockpitRestoration(
            camera: AviationMapCameraState(
                center: AviationMapCoordinate(latitude: 32.1, longitude: 34.8),
                zoomLevel: 9,
                direction: 17,
                pitch: 2
            ),
            isCameraUserControlled: true,
            selectedCallout: nil,
            focusRequest: AviationMapFocusRequest(mode: .overview)
        )
        let active = PositionCheckState.idle.transition(
            .holdCompleted(availability: .ready(sample()), restoration: restoration),
            now: .zero
        ).state

        let degraded = active.transition(
            .locationAvailabilityChanged(.unavailable(.signalLost)),
            now: .seconds(2)
        )

        #expect(degraded.state == .transientFailure(.signalLost))
        #expect(degraded.state.activeSession == nil)
        #expect(degraded.effect == .endDisclosure(restoration: restoration))
    }

    @Test("Every unusable availability fails closed with its structured cause")
    func everyUnusableAvailabilityFailsClosed() throws {
        let cases: [(LocationAvailability, PositionCheckState.Failure)] = [
            (.acquiring, .signalLost),
            (.unavailable(.servicesDisabled), .servicesDisabled),
            (.unavailable(.stale), .staleFix),
            (.unavailable(.invalidAccuracy), .poorAccuracy),
            (.unavailable(.insufficientAccuracy), .poorAccuracy),
            (.unavailable(.outOfOrder), .staleFix),
            (.unavailable(.sourceFailure), .sourceFailure),
            (.permissionRequired(.denied), .permissionRevoked(.denied)),
            (.permissionRequired(.restricted), .permissionRevoked(.restricted))
        ]

        for (availability, expectedFailure) in cases {
            let active = PositionCheckState.idle.transition(
                .holdCompleted(availability: .ready(sample()), restoration: .empty),
                now: .zero
            ).state

            let degraded = active.transition(
                .locationAvailabilityChanged(availability),
                now: .seconds(2)
            )

            #expect(degraded.state == .transientFailure(expectedFailure))
            #expect(degraded.state.activeSession == nil)
            #expect(degraded.effect == .endDisclosure(restoration: .empty))
        }
    }

    @Test("Acquisition degradation cancels its deadline and exposes the structured cause")
    func acquisitionDegradationCancelsDeadline() throws {
        let acquiring = PositionCheckState.idle.transition(
            .holdCompleted(availability: .acquiring, restoration: .empty),
            now: .zero
        ).state

        let degraded = acquiring.transition(
            .locationAvailabilityChanged(.permissionRequired(.denied)),
            now: .seconds(2)
        )

        #expect(degraded.state == .transientFailure(.permissionRevoked(.denied)))
        #expect(degraded.effect == .cancelDeadline)
    }

    @Test("Inactive scene and flight loss terminate acquisition and disclosure")
    func lifecycleLossTerminatesEverySession() throws {
        let acquiring = PositionCheckState.idle.transition(
            .holdCompleted(availability: .acquiring, restoration: .empty),
            now: .zero
        ).state
        let active = PositionCheckState.idle.transition(
            .holdCompleted(availability: .ready(sample()), restoration: .empty),
            now: .zero
        ).state

        #expect(acquiring.transition(.sceneBecameInactive, now: .seconds(1)).state == .idle)
        #expect(active.transition(.activeFlightLost, now: .seconds(1)).state == .idle)
        #expect(active.transition(.activeFlightLost, now: .seconds(1)).effect == .endDisclosure(restoration: .empty))
    }

    private func sample() -> AircraftLocationSample {
        AircraftLocationSample(
            coordinate: WGS84Coordinate(latitudeDegrees: 32.1, longitudeDegrees: 34.8),
            observedAt: Date(timeIntervalSince1970: 1_000),
            horizontalAccuracyMeters: 35,
            trueCourseDegrees: 72,
            courseAccuracyDegrees: 5,
            groundSpeedMetersPerSecond: 40,
            speedAccuracyMetersPerSecond: 1
        )
    }
}
