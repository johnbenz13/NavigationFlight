import Foundation
import FlightEvidenceCore
import Observation

nonisolated struct FlightDebrief: Equatable, Sendable {
    enum RecordingState: Equatable, Sendable {
        case complete
        case incomplete
        case manuallyEnded
        case active
        case recoverable
    }

    let recordingID: UUID
    let title: String
    let routeName: String
    let startedAt: Date
    let endedAt: Date
    let recordingState: RecordingState
    let gpsCoverage: GPSCoverageState
    let plannedRoute: [WGS84Coordinate]
    let plannedDurationSeconds: Int?
    let plannedDriftAngleDegrees: Double?
    let trackSegments: [FlightDebriefTrackSegment]
    let events: [FlightDebriefEvent]
    let duration: Duration
    let gpsCoverageFraction: Double?
    let plannedDistanceMeters: Double?
    let actualDistanceMeters: Double
    let altitudeObservations: [FlightDebriefObservation]
    let groundSpeedObservations: [FlightDebriefObservation]

    var hasTrustworthyPosition: Bool {
        trackSegments.contains { segment in
            segment.samples.contains { $0.horizontalAccuracyMeters <= 50 }
        }
    }

    var hasTrackGaps: Bool {
        trackSegments.filter { !$0.samples.isEmpty }.count > 1
    }

    var gpsCoverageText: String {
        if gpsCoverage == .unavailable { return String(localized: "Unavailable") }
        if gpsCoverage == .partial || hasTrackGaps {
            // The fraction is based on explicit gap events; segmented evidence may
            // still report 1 when those events are missing. Do not imply completeness.
            return String(localized: "Partial")
        }
        guard let fraction = gpsCoverageFraction else { return String(localized: "Unavailable") }
        return fraction.formatted(.percent.precision(.fractionLength(0)))
    }

    func selection(at elapsed: Duration) -> FlightDebriefSelection {
        let clamped = min(max(elapsed, .zero), duration)
        let date = startedAt.addingTimeInterval(clamped.timeInterval)
        let interpolated = trackSegments.compactMap { $0.sample(at: date) }
            .filter { $0.horizontalAccuracyMeters <= 50 }
            .min { abs($0.observedAt.timeIntervalSince(date)) < abs($1.observedAt.timeIntervalSince(date)) }
        let sample = interpolated ?? trackSegments
            .compactMap { $0.nearestSample(to: date) }
            .filter { $0.horizontalAccuracyMeters <= 50 }
            .min { abs($0.observedAt.timeIntervalSince(date)) < abs($1.observedAt.timeIntervalSince(date)) }
        let event = events.min { abs($0.elapsed.timeInterval - clamped.timeInterval) < abs($1.elapsed.timeInterval - clamped.timeInterval) }
        return FlightDebriefSelection(elapsed: clamped, sample: sample, event: event)
    }
}

nonisolated struct FlightDebriefTrackSegment: Equatable, Sendable, Identifiable {
    let id: UUID
    let samples: [RecordedTrackSample]

    func nearestSample(to date: Date) -> RecordedTrackSample? {
        guard !samples.isEmpty else { return nil }
        var lower = 0
        var upper = samples.count
        while lower < upper {
            let middle = (lower + upper) / 2
            if samples[middle].observedAt < date { lower = middle + 1 } else { upper = middle }
        }
        let candidates = [lower - 1, lower].filter { samples.indices.contains($0) }.map { samples[$0] }
        return candidates.min { abs($0.observedAt.timeIntervalSince(date)) < abs($1.observedAt.timeIntervalSince(date)) }
    }

    func sample(at date: Date) -> RecordedTrackSample? {
        guard let first = samples.first, let last = samples.last,
              first.observedAt <= date, date <= last.observedAt else { return nil }
        guard let laterIndex = samples.firstIndex(where: { $0.observedAt >= date }) else { return last }
        guard laterIndex > 0 else { return samples[laterIndex] }
        let earlier = samples[laterIndex - 1]
        let later = samples[laterIndex]
        let interval = later.observedAt.timeIntervalSince(earlier.observedAt)
        guard interval > 0 else { return earlier }
        let fraction = date.timeIntervalSince(earlier.observedAt) / interval
        func interpolate(_ lhs: Double?, _ rhs: Double?) -> Double? {
            guard let lhs, let rhs else { return lhs ?? rhs }
            return lhs + (rhs - lhs) * fraction
        }
        let reliableCourseSample = samples[...laterIndex].last {
            $0.observedAt <= date
                && ($0.groundSpeedMetersPerSecond ?? 0) >= 2
                && $0.courseDegrees != nil
                && ($0.courseAccuracyDegrees ?? .infinity) <= 30
        }
        return RecordedTrackSample(
            coordinate: .init(
                latitudeDegrees: earlier.coordinate.latitudeDegrees + (later.coordinate.latitudeDegrees - earlier.coordinate.latitudeDegrees) * fraction,
                longitudeDegrees: earlier.coordinate.longitudeDegrees + (later.coordinate.longitudeDegrees - earlier.coordinate.longitudeDegrees) * fraction
            ),
            observedAt: date,
            horizontalAccuracyMeters: max(earlier.horizontalAccuracyMeters, later.horizontalAccuracyMeters),
            altitudeMeters: interpolate(earlier.altitudeMeters, later.altitudeMeters),
            verticalAccuracyMeters: interpolate(earlier.verticalAccuracyMeters, later.verticalAccuracyMeters),
            groundSpeedMetersPerSecond: interpolate(earlier.groundSpeedMetersPerSecond, later.groundSpeedMetersPerSecond),
            speedAccuracyMetersPerSecond: interpolate(earlier.speedAccuracyMetersPerSecond, later.speedAccuracyMetersPerSecond),
            courseDegrees: reliableCourseSample?.courseDegrees,
            courseAccuracyDegrees: reliableCourseSample?.courseAccuracyDegrees,
            barometricAltitudeMeters: interpolate(earlier.barometricAltitudeMeters, later.barometricAltitudeMeters),
            deviceHeadingDegrees: nil,
            deviceHeadingAccuracyDegrees: nil
        )
    }
}

nonisolated struct FlightDebriefObservation: Equatable, Sendable, Identifiable {
    enum Source: String, Equatable, Sendable { case gpsAltitude, barometricAltitude, groundSpeed }
    let id: String
    let segmentID: UUID
    let elapsed: Duration
    let value: Double
    let source: Source
}

nonisolated struct FlightDebriefEvent: Equatable, Sendable, Identifiable {
    enum Position: Equatable, Sendable {
        case direct(WGS84Coordinate, accuracyMeters: Double)
        case correlated(WGS84Coordinate, delta: Duration, accuracyMeters: Double)
        case unavailable
    }

    let id: UUID
    let sequence: UInt64
    let elapsed: Duration
    let occurredAt: Date
    let origin: RecordedFlightEvent.Origin
    let title: String
    let position: Position
}

nonisolated struct FlightDebriefSelection: Equatable, Sendable {
    let elapsed: Duration
    let sample: RecordedTrackSample?
    let event: FlightDebriefEvent?
}

nonisolated struct FlightDebriefCorrelationPolicy: Equatable, Sendable {
    let version: Int
    let maximumTimeDelta: Duration
    let maximumHorizontalAccuracyMeters: Double

    static let current = Self(version: 1, maximumTimeDelta: .seconds(10), maximumHorizontalAccuracyMeters: 50)
}

nonisolated struct FlightDebriefProjector: Sendable {
    let correlationPolicy: FlightDebriefCorrelationPolicy

    init(correlationPolicy: FlightDebriefCorrelationPolicy = .current) {
        self.correlationPolicy = correlationPolicy
    }

    func project(_ evidence: FlightEvidenceSnapshot) throws -> FlightDebrief {
        let snapshot = evidence.recording
        let recording = snapshot.recording
        let closure = recording.closure
        let plan = recording.flightPlanSnapshot.sourceData.flatMap { try? FPLNavDecoder().decode($0) }
        let segments = snapshot.trackSegments.map {
            FlightDebriefTrackSegment(id: $0.id, samples: $0.samples.sorted { $0.observedAt < $1.observedAt })
        }
        let events = snapshot.events.filter { $0.payload != .cockpitPresentationChanged }
            .sorted { $0.sequence < $1.sequence }.map {
            FlightDebriefEvent(
                id: $0.id,
                sequence: $0.sequence,
                elapsed: $0.elapsed,
                occurredAt: $0.occurredAt,
                origin: $0.origin,
                title: title(for: $0.payload, plan: plan),
                position: position(for: $0, in: segments)
            )
        }
        let plannedDurationSeconds: Int? = switch plan?.plannedNavigation {
        case .emptyPlan(let navigation), .eligible(let navigation):
            navigation.legs.reduce(0) { $0 + $1.noWind.durationSeconds }
        case .unavailableLegacyFormat, nil:
            nil
        }
        return FlightDebrief(
            recordingID: recording.id,
            title: recording.flightPlanSnapshot.title,
            routeName: routeName(plan),
            startedAt: recording.startedAt,
            endedAt: closure?.closedAt ?? evidence.capturedAt,
            recordingState: recordingState(for: evidence),
            gpsCoverage: recording.gpsCoverage,
            plannedRoute: plan?.waypoints.map(\.position) ?? [],
            plannedDurationSeconds: plannedDurationSeconds,
            plannedDriftAngleDegrees: plan?.parameters.driftAngle.value,
            trackSegments: segments,
            events: events,
            duration: closure?.elapsed ?? .seconds(max(0, evidence.capturedAt.timeIntervalSince(recording.startedAt))),
            gpsCoverageFraction: snapshot.evidenceSummary.gpsCoverageFraction,
            plannedDistanceMeters: plan.map { distance(of: $0.waypoints.map(\.position)) },
            actualDistanceMeters: segments.reduce(0) { $0 + distance(of: $1.samples.map(\.coordinate)) },
            altitudeObservations: segments.flatMap { altitudeObservations($0, startedAt: recording.startedAt) },
            groundSpeedObservations: segments.flatMap { segment in
                segment.samples.compactMap { sample in
                    sample.groundSpeedMetersPerSecond.map {
                        FlightDebriefObservation(id: "speed-\(sample.observedAt.timeIntervalSinceReferenceDate)", segmentID: segment.id, elapsed: .seconds(sample.observedAt.timeIntervalSince(recording.startedAt)), value: $0, source: .groundSpeed)
                    }
                }
            }
        )
    }

    private func recordingState(for evidence: FlightEvidenceSnapshot) -> FlightDebrief.RecordingState {
        switch evidence.sourceState {
        case .active:
            return .active
        case .recoverable:
            return .recoverable
        case .closed:
            guard let closure = evidence.recording.recording.closure else { return .incomplete }
            if closure.cause == .manual { return .manuallyEnded }
            return closure.outcome == .complete ? .complete : .incomplete
        }
    }

    private func position(for event: RecordedFlightEvent, in segments: [FlightDebriefTrackSegment]) -> FlightDebriefEvent.Position {
        if case .positionCheckEnded(.disclosed(let sample)) = event.payload {
            return .direct(sample.coordinate, accuracyMeters: sample.horizontalAccuracyMeters)
        }
        guard let segment = segments.first(where: {
            guard let first = $0.samples.first?.observedAt, let last = $0.samples.last?.observedAt else { return false }
            return first <= event.occurredAt && event.occurredAt <= last
        }), let sample = segment.nearestSample(to: event.occurredAt) else { return .unavailable }
        let delta = sample.observedAt.timeIntervalSince(event.occurredAt)
        guard abs(delta) <= correlationPolicy.maximumTimeDelta.timeInterval,
              sample.horizontalAccuracyMeters <= correlationPolicy.maximumHorizontalAccuracyMeters else { return .unavailable }
        return .correlated(sample.coordinate, delta: .seconds(delta), accuracyMeters: sample.horizontalAccuracyMeters)
    }

    private func altitudeObservations(_ segment: FlightDebriefTrackSegment, startedAt: Date) -> [FlightDebriefObservation] {
        segment.samples.flatMap { sample in
            let elapsed = Duration.seconds(sample.observedAt.timeIntervalSince(startedAt))
            return [
                sample.altitudeMeters.map { FlightDebriefObservation(id: "gps-\(sample.observedAt.timeIntervalSinceReferenceDate)", segmentID: segment.id, elapsed: elapsed, value: $0, source: .gpsAltitude) },
                sample.barometricAltitudeMeters.map { FlightDebriefObservation(id: "baro-\(sample.observedAt.timeIntervalSinceReferenceDate)", segmentID: segment.id, elapsed: elapsed, value: $0, source: .barometricAltitude) },
            ].compactMap { $0 }
        }
    }

    private func routeName(_ plan: FlightPlan?) -> String {
        guard let first = plan?.waypoints.first?.name, let last = plan?.waypoints.last?.name else { return "Recorded Flight" }
        return first == last ? first : "\(first) → \(last)"
    }

    private func title(for payload: RecordedFlightEventPayload, plan: FlightPlan?) -> String {
        switch payload {
        case .cockpitPresentationChanged: "Checklist presentation changed"
        case .recordingStarted: "Recording began"
        case .legStarted: "Leg started"
        case .destinationIdentified: "Destination identified"
        case .identificationPointReached(let key): "\(identificationPointName(key, plan: plan)) marked reached"
        case .pendingRouteAmendmentConfirmed: "Route amendment confirmed for later"
        case .amendmentDepartureIdentified: "Departure point identified"
        case .waypointReached: "Waypoint marked reached"
        case .automaticNextLegTransition: "Advanced to next leg"
        case .finalWaypointReached: "Final waypoint reached"
        case .automaticLegRecovery: "Leg recovered"
        case .etaRevised: "ETA revised"
        case .headingRevised: "Heading revised"
        case .reachUndone: "Reach undone"
        case .positionCheckRequested: "Position check requested"
        case .positionCheckEnded: "Position check ended"
        case .storageDegraded: "Recording storage degraded"
        case .locationAvailabilityChanged: "Location availability changed"
        case .physicalStateChanged(_, let to): "Physical phase: \(to.rawValue)"
        case .physicalStateCorrected: "Physical phase corrected"
        case .navigationCompleted: "Navigation completed"
        case .recoveryContinued: "Recovery continued"
        case .manualEnd: "Flight ended manually"
        case .recordingClosed: "Recording closed"
        }
    }

    private func identificationPointName(_ key: IdentificationPointKey, plan: FlightPlan?) -> String {
        guard let index = plan?.identificationPoints.firstIndex(where: { $0.id == key.identificationPointID }) else { return "Identification point" }
        return "IP\(index + 1)"
    }

    private func distance(of coordinates: [WGS84Coordinate]) -> Double {
        zip(coordinates, coordinates.dropFirst()).reduce(0) { $0 + Self.distance(from: $1.0, to: $1.1) }
    }

    static func distance(from lhs: WGS84Coordinate, to rhs: WGS84Coordinate) -> Double {
        let radius = 6_371_000.0
        let latitudeDelta = (rhs.latitudeDegrees - lhs.latitudeDegrees) * .pi / 180
        let longitudeDelta = (rhs.longitudeDegrees - lhs.longitudeDegrees) * .pi / 180
        let lhsLatitude = lhs.latitudeDegrees * .pi / 180
        let rhsLatitude = rhs.latitudeDegrees * .pi / 180
        let value = sin(latitudeDelta / 2) * sin(latitudeDelta / 2) + cos(lhsLatitude) * cos(rhsLatitude) * sin(longitudeDelta / 2) * sin(longitudeDelta / 2)
        return radius * 2 * atan2(sqrt(value), sqrt(1 - value))
    }
}

nonisolated enum FlightDebriefProjectionError: Error, Equatable, Sendable {
    case recordingNotClosed
}

private extension Duration {
    nonisolated var timeInterval: TimeInterval {
        let components = self.components
        return Double(components.seconds) + Double(components.attoseconds) / 1e18
    }
}

nonisolated protocol FlightDebriefPlaybackClock: Sendable {
    func sleep(for duration: Duration) async throws
}

nonisolated struct ContinuousFlightDebriefClock: FlightDebriefPlaybackClock {
    func sleep(for duration: Duration) async throws {
        try await ContinuousClock().sleep(for: duration)
    }
}

@MainActor
@Observable
final class FlightDebriefModel {
    enum State: Equatable { case loading, loaded(FlightDebrief), failed }
    enum PlaybackRate: Int, CaseIterable, Identifiable { case one = 1, two = 2, five = 5; var id: Int { rawValue } }
    enum MapOrientation: Equatable { case northUp, trackUp }
    enum CameraMode: Equatable { case followAircraft, freeLook }
    enum ConsoleMode: Equatable { case compact, analysis }

    private(set) var state: State = .loading
    private(set) var selection: FlightDebriefSelection?
    private(set) var isPlaying = false
    private(set) var mapOrientation: MapOrientation = .northUp
    private(set) var cameraMode: CameraMode = .followAircraft
    private(set) var cameraRequest = 0
    private(set) var fitsFullFlight = false
    private(set) var areDriftLinesVisible = true
    private(set) var consoleMode: ConsoleMode = .compact
    var playbackRate: PlaybackRate = .one

    private let loadEvidence: @Sendable () async throws -> FlightEvidenceSnapshot
    private let projector: FlightDebriefProjector
    private let clock: any FlightDebriefPlaybackClock
    private var playbackTask: Task<Void, Never>?

    init(loadEvidence: @escaping @Sendable () async throws -> FlightEvidenceSnapshot, projector: FlightDebriefProjector = .init(), clock: any FlightDebriefPlaybackClock = ContinuousFlightDebriefClock()) {
        self.loadEvidence = loadEvidence
        self.projector = projector
        self.clock = clock
    }

    func load() async {
        pause()
        state = .loading
        do {
            try Task.checkCancellation()
            let debrief = try projector.project(try await loadEvidence())
            try Task.checkCancellation()
            state = .loaded(debrief)
            let firstTrustworthy = debrief.trackSegments.flatMap(\.samples)
                .filter { $0.horizontalAccuracyMeters <= 50 }
                .min { $0.observedAt < $1.observedAt }
            let initialElapsed = firstTrustworthy.map { Duration.seconds($0.observedAt.timeIntervalSince(debrief.startedAt)) } ?? .zero
            selection = debrief.selection(at: initialElapsed)
            mapOrientation = .northUp
            cameraMode = .followAircraft
            fitsFullFlight = false
            consoleMode = .compact
        } catch is CancellationError {
            return
        } catch {
            state = .failed
        }
    }

    func seek(to time: Duration) {
        guard case .loaded(let debrief) = state else { return }
        selection = debrief.selection(at: time)
        refocusAircraft()
    }

    func select(eventID: UUID) {
        guard case .loaded(let debrief) = state, let event = debrief.events.first(where: { $0.id == eventID }) else { return }
        let replaySelection = debrief.selection(at: event.elapsed)
        selection = FlightDebriefSelection(
            elapsed: replaySelection.elapsed,
            sample: replaySelection.sample,
            event: event
        )
        refocusAircraft()
    }

    func toggleOrientation() {
        mapOrientation = mapOrientation == .northUp ? .trackUp : .northUp
        refocusAircraft()
    }

    func enterFreeLook() {
        cameraMode = .freeLook
        fitsFullFlight = false
    }

    func recenter() { refocusAircraft() }

    func showFullFlight() {
        cameraMode = .freeLook
        fitsFullFlight = true
        cameraRequest += 1
    }

    func toggleDriftLines() { areDriftLinesVisible.toggle() }

    func toggleConsoleMode() {
        consoleMode = consoleMode == .compact ? .analysis : .compact
    }

    private func refocusAircraft() {
        guard selection?.sample != nil else { return }
        cameraMode = .followAircraft
        fitsFullFlight = false
        cameraRequest += 1
    }

    func play() {
        guard !isPlaying, case .loaded = state else { return }
        isPlaying = true
        playbackTask = Task { [weak self] in
            while !Task.isCancelled {
                do { try await self?.clock.sleep(for: .milliseconds(100)) } catch { return }
                guard let self, case .loaded(let debrief) = self.state, let selection = self.selection else { return }
                let next = selection.elapsed + .milliseconds(100 * self.playbackRate.rawValue)
                if next >= debrief.duration { self.seek(to: debrief.duration); self.pause(); return }
                self.seek(to: next)
            }
        }
    }

    func pause() {
        playbackTask?.cancel()
        playbackTask = nil
        isPlaying = false
    }
}
