import Foundation
import Testing
@testable import NavigationFlight

@Suite("Aircraft location service")
struct AircraftLocationServiceTests {
    @Test("Denied authorization remains a structured permission cause")
    func deniedAuthorizationIsPublished() async {
        let source = ControllableAircraftLocationSource()
        let service = AircraftLocationService(source: source)

        var updates = await service.availabilityUpdates().makeAsyncIterator()
        await service.startMonitoring()
        #expect(await updates.next() == .acquiring)
        await source.send(.authorization(.denied))

        #expect(await updates.next() == .permissionRequired(.denied))
    }

    @Test("Multiple observers share one acquisition stream")
    func multipleObserversShareOneStream() async {
        let source = ControllableAircraftLocationSource()
        let service = AircraftLocationService(source: source)
        var first = await service.availabilityUpdates().makeAsyncIterator()
        var second = await service.availabilityUpdates().makeAsyncIterator()

        await service.startMonitoring()

        #expect(await first.next() == .acquiring)
        #expect(await second.next() == .acquiring)
        await source.send(.authorization(.whenInUse))
        #expect(await first.next() == .acquiring)
        #expect(await second.next() == .acquiring)
        #expect(await source.streamCount == 1)
    }

    @Test("Recording and Position Check scopes coexist without cancelling each other")
    func monitoringScopesCoexist() async {
        let source = ControllableAircraftLocationSource()
        let service = AircraftLocationService(source: source)
        var recordingEvents = await service.recordingUpdates().makeAsyncIterator()

        await service.startMonitoring(scope: .recording)
        await service.startMonitoring(scope: .positionCheck)
        await source.waitForStreamCount(1)
        await service.stopMonitoring(scope: .positionCheck)
        await source.send(.signalLost)

        #expect(await recordingEvents.next() == .signalLost)
        #expect(await source.streamCount == 1)
    }

    @Test("Recording activity session follows the recording scope exactly once")
    func recordingActivitySessionIsIdempotent() async {
        let source = ControllableAircraftLocationSource()
        let service = AircraftLocationService(source: source)

        await service.startMonitoring(scope: .recording)
        await service.startMonitoring(scope: .recording)
        await service.startMonitoring(scope: .positionCheck)
        await service.stopMonitoring(scope: .positionCheck)

        #expect(await source.recordingActivityStartCount == 1)
        #expect(await source.recordingActivityEndCount == 0)

        await service.stopMonitoring(scope: .recording)
        await service.stopMonitoring(scope: .recording)

        #expect(await source.recordingActivityEndCount == 1)
    }

    @Test("Stopping cancels acquisition and monitoring can restart")
    func cancellationAndRestart() async {
        let source = ControllableAircraftLocationSource()
        let service = AircraftLocationService(source: source)
        var updates = await service.availabilityUpdates().makeAsyncIterator()

        await service.startMonitoring()
        #expect(await updates.next() == .acquiring)
        await source.send(.authorization(.whenInUse))
        #expect(await updates.next() == .acquiring)
        await service.stopMonitoring()
        await service.startMonitoring()
        #expect(await updates.next() == .acquiring)
        await source.waitForStreamCount(2)
        await source.send(.authorization(.whenInUse))
        #expect(await updates.next() == .acquiring)
        #expect(await source.streamCount == 2)
    }

    @Test("Only the latest accepted fix is published")
    func latestFixReplacesPreviousFix() async {
        let now = Date(timeIntervalSince1970: 1_000)
        let source = ControllableAircraftLocationSource()
        let service = AircraftLocationService(source: source)
        var updates = await service.availabilityUpdates().makeAsyncIterator()
        let firstSample = sample(observedAt: now)
        let secondSample = sample(observedAt: now.addingTimeInterval(1))

        await service.startMonitoring()
        #expect(await updates.next() == .acquiring)
        await source.send(.sample(firstSample, receivedAt: now))
        #expect(await updates.next() == .ready(firstSample))
        await source.send(.sample(secondSample, receivedAt: now.addingTimeInterval(1)))
        #expect(await updates.next() == .ready(secondSample))
        #expect(await service.availability == .ready(secondSample))
    }

    @Test("A late observer immediately receives the current published availability")
    func lateObserverReceivesCurrentAvailability() async {
        let now = Date(timeIntervalSince1970: 1_000)
        let source = ControllableAircraftLocationSource()
        let service = AircraftLocationService(source: source)
        let currentSample = sample(observedAt: now)

        await service.startMonitoring(scope: .recording)
        await source.waitForStreamCount(1)
        await source.send(.sample(currentSample, receivedAt: now))
        while await service.availability != .ready(currentSample) {
            await Task.yield()
        }
        var updates = await service.availabilityUpdates().makeAsyncIterator()

        #expect(await updates.next() == .ready(currentSample))
    }

    @Test("Authorization request is delegated as When In Use only")
    func requestsWhenInUseAuthorization() async {
        let source = ControllableAircraftLocationSource()
        let service = AircraftLocationService(source: source)

        await service.requestWhenInUseAuthorization()

        #expect(await source.authorizationRequestCount == 1)
    }

    private func sample(observedAt: Date) -> AircraftLocationSample {
        AircraftLocationSample(
            coordinate: WGS84Coordinate(latitudeDegrees: 32, longitudeDegrees: 34.8),
            observedAt: observedAt,
            horizontalAccuracyMeters: 50,
            trueCourseDegrees: 90,
            courseAccuracyDegrees: 10,
            groundSpeedMetersPerSecond: 20,
            speedAccuracyMetersPerSecond: 1
        )
    }
}

private actor ControllableAircraftLocationSource: AircraftLocationSource {
    private var continuation: AsyncThrowingStream<LocationSourceEvent, Error>.Continuation?
    private var pendingEvents: [LocationSourceEvent] = []
    private(set) var streamCount = 0
    private(set) var authorizationRequestCount = 0
    private(set) var recordingActivityStartCount = 0
    private(set) var recordingActivityEndCount = 0
    private var streamWaiters: [(Int, CheckedContinuation<Void, Never>)] = []

    nonisolated func updates() -> AsyncThrowingStream<LocationSourceEvent, Error> {
        AsyncThrowingStream { continuation in
            Task { await self.install(continuation) }
        }
    }

    func requestWhenInUseAuthorization() {
        authorizationRequestCount += 1
    }

    func beginRecordingActivity() {
        recordingActivityStartCount += 1
    }

    func endRecordingActivity() {
        recordingActivityEndCount += 1
    }

    func send(_ event: LocationSourceEvent) {
        if let continuation {
            continuation.yield(event)
        } else {
            pendingEvents.append(event)
        }
    }

    func waitForStreamCount(_ expectedCount: Int) async {
        guard streamCount < expectedCount else { return }
        await withCheckedContinuation { continuation in
            streamWaiters.append((expectedCount, continuation))
        }
    }

    private func install(
        _ continuation: AsyncThrowingStream<LocationSourceEvent, Error>.Continuation
    ) {
        streamCount += 1
        self.continuation = continuation
        pendingEvents.forEach { continuation.yield($0) }
        pendingEvents.removeAll()
        let readyWaiters = streamWaiters.filter { streamCount >= $0.0 }
        streamWaiters.removeAll { streamCount >= $0.0 }
        readyWaiters.forEach { $0.1.resume() }
    }

}
