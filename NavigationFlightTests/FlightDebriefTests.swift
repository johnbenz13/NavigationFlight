import Foundation
import FlightEvidenceCore
import Testing
@testable import NavigationFlight

@Suite("Flight debrief")
struct FlightDebriefTests {
    @Test("Retained recording states remain explicit and provisional snapshots preserve evidence")
    func retainedRecordingStates() throws {
        let fixture = try makeEvidence(eventTime: 9, segmentTimes: [[0, 10], [30, 40]])
        let closed = try FlightDebriefProjector().project(fixture.evidence)
        let activeEvidence = FlightEvidenceSnapshot(
            capturedAt: fixture.evidence.capturedAt,
            sourceState: .active,
            recording: fixture.evidence.recording,
            context: fixture.evidence.context
        )
        let recoverableEvidence = FlightEvidenceSnapshot(
            capturedAt: fixture.evidence.capturedAt,
            sourceState: .recoverable,
            recording: fixture.evidence.recording,
            context: fixture.evidence.context
        )

        #expect(closed.recordingState == .manuallyEnded)
        #expect(closed.hasTrackGaps)
        #expect(try FlightDebriefProjector().project(activeEvidence).recordingState == .active)
        #expect(try FlightDebriefProjector().project(recoverableEvidence).recordingState == .recoverable)
    }

    @Test("Action-only evidence retains events without inventing a position")
    func actionOnlyEvidence() throws {
        let fixture = try makeEvidence(eventTime: 9, segmentTimes: [])
        let debrief = try FlightDebriefProjector().project(fixture.evidence)

        #expect(!debrief.hasTrustworthyPosition)
        #expect(debrief.trackSegments.isEmpty)
        #expect(debrief.events.count == 1)
        #expect(debrief.events[0].position == .unavailable)
    }

    @Test("Correlation stays inside a track segment and preserves event time")
    func correlationDoesNotCrossGap() throws {
        let fixture = try makeEvidence(eventTime: 30, segmentTimes: [[0, 10], [40, 50]])
        let debrief = try FlightDebriefProjector().project(fixture.evidence)

        #expect(debrief.events.first(where: { $0.id == fixture.eventID })?.occurredAt == fixture.startedAt.addingTimeInterval(30))
        #expect(debrief.events.first(where: { $0.id == fixture.eventID })?.position == .unavailable)
        #expect(debrief.trackSegments.count == 2)
    }

    @Test("Nearby accurate samples correlate deterministically")
    func correlatedPosition() throws {
        let fixture = try makeEvidence(eventTime: 9, segmentTimes: [[0, 10, 20]])
        let event = try #require(FlightDebriefProjector().project(fixture.evidence).events.first { $0.id == fixture.eventID })

        guard case .correlated(let coordinate, let delta, let accuracy) = event.position else {
            Issue.record("Expected correlated position")
            return
        }
        #expect(abs(coordinate.latitudeDegrees - 32.01) < 0.000_001)
        #expect(abs(coordinate.longitudeDegrees - 34.81) < 0.000_001)
        #expect(delta == .seconds(1))
        #expect(accuracy == 8)
    }

    @Test("Direct event evidence is never replaced by correlation")
    func directPositionWins() throws {
        let fixture = try makeEvidence(eventTime: 9, segmentTimes: [[0, 10, 20]], direct: true)
        let event = try #require(FlightDebriefProjector().project(fixture.evidence).events.first { $0.id == fixture.eventID })

        #expect(event.position == .direct(.init(latitudeDegrees: 31.9, longitudeDegrees: 34.7), accuracyMeters: 3))
    }

    @Test("Historical position interpolates only inside one continuous segment")
    func historicalPositionInterpolationStopsAtGaps() throws {
        let fixture = try makeEvidence(eventTime: 9, segmentTimes: [[0, 10], [40, 50]])
        let debrief = try FlightDebriefProjector().project(fixture.evidence)

        let inside = try #require(debrief.selection(at: .seconds(5)).sample)
        #expect(abs(inside.coordinate.latitudeDegrees - 32.005) < 0.000_001)
        #expect(inside.courseDegrees == 90)
        let gap = try #require(debrief.selection(at: .seconds(25)).sample)
        #expect(abs(gap.coordinate.latitudeDegrees - 32.01) < 0.000_001)
        #expect(abs(gap.coordinate.longitudeDegrees - 34.81) < 0.000_001)
    }

    @Test("Low-speed replay retains the last reliable course in its segment")
    func lowSpeedReplayRetainsLastReliableCourse() throws {
        let startedAt = Date(timeIntervalSince1970: 1_000)
        let segment = FlightDebriefTrackSegment(
            id: UUID(),
            samples: [
                trackSample(at: 0, startedAt: startedAt, speed: 40, course: 87, courseAccuracy: 3),
                trackSample(at: 10, startedAt: startedAt, speed: 1, course: nil, courseAccuracy: nil),
                trackSample(at: 20, startedAt: startedAt, speed: 0, course: 140, courseAccuracy: 80),
            ]
        )

        let sample = try #require(segment.sample(at: startedAt.addingTimeInterval(15)))

        #expect(sample.courseDegrees == 87)
        #expect(sample.courseAccuracyDegrees == 3)
    }

    @Test("Reliable course never carries across a track gap")
    func reliableCourseDoesNotCrossSegments() throws {
        let startedAt = Date(timeIntervalSince1970: 1_000)
        let laterSegment = FlightDebriefTrackSegment(
            id: UUID(),
            samples: [
                trackSample(at: 40, startedAt: startedAt, speed: 1, course: nil, courseAccuracy: nil),
                trackSample(at: 50, startedAt: startedAt, speed: 1, course: nil, courseAccuracy: nil),
            ]
        )

        let sample = try #require(laterSegment.sample(at: startedAt.addingTimeInterval(45)))

        #expect(sample.courseDegrees == nil)
        #expect(sample.courseAccuracyDegrees == nil)
    }

    @MainActor
    @Test("Replay camera transitions remain explicit and seeking refocuses")
    func replayCameraStateTransitions() async throws {
        let fixture = try makeEvidence(eventTime: 9, segmentTimes: [[0, 10, 20]])
        let model = FlightDebriefModel(loadEvidence: { fixture.evidence })
        await model.load()

        #expect(model.mapOrientation == .northUp)
        #expect(model.cameraMode == .followAircraft)
        model.enterFreeLook()
        #expect(model.cameraMode == .freeLook)
        model.toggleOrientation()
        #expect(model.mapOrientation == .trackUp)
        #expect(model.cameraMode == .followAircraft)
        model.showFullFlight()
        #expect(model.cameraMode == .freeLook)
        #expect(model.fitsFullFlight)
        model.seek(to: .seconds(10))
        #expect(model.cameraMode == .followAircraft)
        #expect(!model.fitsFullFlight)
    }

    @MainActor
    @Test("Explicit event selection preserves identity for co-timed events")
    func coTimedEventSelectionPreservesIdentity() async throws {
        let fixture = try makeEvidence(eventTime: 0, segmentTimes: [[0, 10, 20]])
        let model = FlightDebriefModel(loadEvidence: { fixture.evidence })
        await model.load()

        model.select(eventID: fixture.eventID)

        #expect(model.selection?.event?.id == fixture.eventID)
        #expect(model.selection?.elapsed == .zero)
    }

    @MainActor
    @Test("Analysis mode preserves replay and camera state")
    func analysisModePreservesReplayState() async throws {
        let fixture = try makeEvidence(eventTime: 9, segmentTimes: [[0, 10, 20]])
        let model = FlightDebriefModel(loadEvidence: { fixture.evidence })
        await model.load()
        model.seek(to: .seconds(10))
        model.playbackRate = .five
        model.toggleOrientation()
        model.toggleDriftLines()

        let selection = model.selection
        let cameraRequest = model.cameraRequest
        #expect(model.consoleMode == .compact)
        model.toggleConsoleMode()

        #expect(model.consoleMode == .analysis)
        #expect(model.selection == selection)
        #expect(model.playbackRate == .five)
        #expect(model.mapOrientation == .trackUp)
        #expect(model.cameraMode == .followAircraft)
        #expect(model.cameraRequest == cameraRequest)
        #expect(!model.areDriftLinesVisible)
    }

    @MainActor
    @Test("Injected clock advances selection at the chosen rate without changing evidence")
    func injectedClockPlayback() async throws {
        let fixture = try makeEvidence(eventTime: 9, segmentTimes: [[0, 10, 20]])
        let clock = TestDebriefClock()
        let model = FlightDebriefModel(loadEvidence: { fixture.evidence }, clock: clock)
        await model.load()
        model.playbackRate = .five
        model.play()
        await clock.waitForSleeper()
        await clock.advance()
        await clock.waitForSleeper()

        #expect(model.selection?.elapsed == .milliseconds(500))
        if case .loaded(let debrief) = model.state {
            #expect(debrief.events.first(where: { $0.id == fixture.eventID })?.elapsed == .seconds(9))
        } else {
            Issue.record("Expected loaded state")
        }
        model.pause()
    }

    private func makeEvidence(eventTime: TimeInterval, segmentTimes: [[TimeInterval]], direct: Bool = false) throws -> Fixture {
        let startedAt = Date(timeIntervalSince1970: 1_000)
        let eventID = UUID()
        let legID = UUID()
        var recording = try FlightRecording.promoteForStartLeg(
            id: UUID(),
            flightID: UUID(),
            flightPlanSnapshot: .init(id: UUID(), title: "Synthetic Flight", legIDs: [legID], sourceData: nil),
            legID: legID,
            startedAt: startedAt,
            eventIDs: [UUID(), UUID()]
        ).recording
        _ = try recording.endManually(at: startedAt.addingTimeInterval(60), elapsed: .seconds(60), eventIDs: [UUID(), UUID()])
        let payload: RecordedFlightEventPayload = direct
            ? .positionCheckEnded(outcome: .disclosed(sample: .init(coordinate: .init(latitudeDegrees: 31.9, longitudeDegrees: 34.7), observedAt: startedAt.addingTimeInterval(eventTime), horizontalAccuracyMeters: 3)))
            : .waypointReached(legID: UUID())
        let event = RecordedFlightEvent(id: eventID, sequence: 2, occurredAt: startedAt.addingTimeInterval(eventTime), elapsed: .seconds(eventTime), origin: .pilot, payload: payload)
        let segments = segmentTimes.map { times in
            RecordedTrackSegment(id: UUID(), samples: times.map { time in
                RecordedTrackSample(
                    coordinate: .init(latitudeDegrees: 32 + time / 1_000, longitudeDegrees: 34.8 + time / 1_000),
                    observedAt: startedAt.addingTimeInterval(time),
                    horizontalAccuracyMeters: 8,
                    altitudeMeters: 100 + time,
                    verticalAccuracyMeters: 3,
                    groundSpeedMetersPerSecond: 40,
                    speedAccuracyMetersPerSecond: 1,
                    courseDegrees: 90,
                    courseAccuracyDegrees: 2
                )
            })
        }
        let evidence = FlightEvidenceSnapshot(
            capturedAt: startedAt.addingTimeInterval(60),
            recording: .init(recording: recording, events: [event], trackSegments: segments),
            context: .init(appVersion: "1", appBuild: "1", platform: "iPadOS", osVersion: "27")
        )
        return Fixture(evidence: evidence, eventID: eventID, startedAt: startedAt)
    }

    private func trackSample(
        at elapsed: TimeInterval,
        startedAt: Date,
        speed: Double?,
        course: Double?,
        courseAccuracy: Double?
    ) -> RecordedTrackSample {
        let latitude = 32.0 + elapsed / 1_000
        let longitude = 34.8 + elapsed / 1_000
        return RecordedTrackSample(
            coordinate: .init(latitudeDegrees: latitude, longitudeDegrees: longitude),
            observedAt: startedAt.addingTimeInterval(elapsed),
            horizontalAccuracyMeters: 8,
            altitudeMeters: nil,
            verticalAccuracyMeters: nil,
            groundSpeedMetersPerSecond: speed,
            speedAccuracyMetersPerSecond: 1,
            courseDegrees: course,
            courseAccuracyDegrees: courseAccuracy
        )
    }
}

private struct Fixture: Sendable {
    let evidence: FlightEvidenceSnapshot
    let eventID: UUID
    let startedAt: Date
}

private actor TestDebriefClock: FlightDebriefPlaybackClock {
    private var continuations: [CheckedContinuation<Void, Error>] = []

    func sleep(for duration: Duration) async throws {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                continuations.append(continuation)
            }
        } onCancel: {
        }
    }

    func waitForSleeper() async {
        while continuations.isEmpty { await Task.yield() }
    }

    func advance() {
        guard !continuations.isEmpty else { return }
        continuations.removeFirst().resume()
    }
}
