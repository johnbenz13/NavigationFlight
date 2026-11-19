import FlightEvidenceCore
import Foundation

nonisolated struct FlightEvidenceContext: Equatable, Sendable {
    let appVersion: String
    let appBuild: String
    let platform: String
    let osVersion: String
    let detectorPolicy: PhysicalFlightDetectionPolicySnapshot?

    init(
        appVersion: String,
        appBuild: String,
        platform: String,
        osVersion: String,
        detectorPolicy: PhysicalFlightDetectionPolicySnapshot? = nil
    ) {
        self.appVersion = appVersion
        self.appBuild = appBuild
        self.platform = platform
        self.osVersion = osVersion
        self.detectorPolicy = detectorPolicy
    }

    static var current: Self {
        let info = Bundle.main.infoDictionary
        return Self(
            appVersion: info?["CFBundleShortVersionString"] as? String ?? "unavailable",
            appBuild: info?["CFBundleVersion"] as? String ?? "unavailable",
            platform: "iOS",
            osVersion: ProcessInfo.processInfo.operatingSystemVersionString,
            detectorPolicy: .production
        )
    }
}

nonisolated struct FlightEvidenceSnapshot: Equatable, Sendable {
    let capturedAt: Date
    let recording: FlightRecordingReadSnapshot
    let context: FlightEvidenceContext
}

nonisolated enum FlightEvidenceMappingError: Error, Equatable, Sendable {
    case recordingNotClosed(UUID)
    case durationOutOfRange
}

nonisolated struct FlightEvidenceMapper: Sendable {
    func bundle(
        from snapshot: FlightEvidenceSnapshot,
        bundleIdentifier: UUID = UUID()
    ) throws -> FlightEvidenceBundleV1 {
        let recording = snapshot.recording.recording
        guard let closure = recording.closure else {
            throw FlightEvidenceMappingError.recordingNotClosed(recording.id)
        }
        return FlightEvidenceBundleV1(
            bundleIdentifier: bundleIdentifier,
            capturedAt: snapshot.capturedAt,
            sourceState: .closed,
            applicationContext: .init(
                appVersion: snapshot.context.appVersion,
                appBuild: snapshot.context.appBuild,
                platform: snapshot.context.platform,
                osVersion: snapshot.context.osVersion
            ),
            detectorPolicyContext: snapshot.context.detectorPolicy.map(detectorPolicyContext),
            recordingManifest: .init(
                recordingIdentifier: recording.id,
                flightIdentifier: recording.flightID,
                startedAt: recording.startedAt,
                physicalState: physicalState(recording.physicalState),
                navigationState: navigationState(recording.navigationState),
                gpsCoverage: gpsCoverage(recording.gpsCoverage)
            ),
            flightPlan: .init(
                identifier: recording.flightPlanSnapshot.id,
                title: recording.flightPlanSnapshot.title,
                legIdentifiers: recording.flightPlanSnapshot.legIDs,
                sourceData: recording.flightPlanSnapshot.sourceData
            ),
            closure: .init(
                outcome: closure.outcome == .complete ? "complete" : "incomplete",
                cause: closureCause(closure.cause),
                closedAt: closure.closedAt,
                elapsedNanoseconds: try nanoseconds(closure.elapsed),
                landingEvidenceAvailable: closure.landingEvidenceAvailable
            ),
            orderedEvents: try snapshot.recording.events.map(event),
            trackSegments: snapshot.recording.trackSegments.map(segment)
        )
    }

    private func event(_ event: RecordedFlightEvent) throws -> FlightEvidenceBundleV1.EventEvidence {
        .init(
            identifier: event.id,
            sequence: event.sequence,
            recordedAt: event.occurredAt,
            elapsedNanoseconds: try nanoseconds(event.elapsed),
            origin: event.origin.rawValue,
            payload: payload(event.payload)
        )
    }

    private func segment(_ segment: RecordedTrackSegment) -> FlightEvidenceBundleV1.TrackSegmentEvidence {
        .init(identifier: segment.id, samples: segment.samples.map { sample in
            .init(
                latitudeDegrees: sample.coordinate.latitudeDegrees,
                longitudeDegrees: sample.coordinate.longitudeDegrees,
                observedAt: sample.observedAt,
                horizontalAccuracyMeters: sample.horizontalAccuracyMeters,
                altitudeMeters: sample.altitudeMeters,
                verticalAccuracyMeters: sample.verticalAccuracyMeters,
                groundSpeedMetersPerSecond: sample.groundSpeedMetersPerSecond,
                speedAccuracyMetersPerSecond: sample.speedAccuracyMetersPerSecond,
                courseDegrees: sample.courseDegrees,
                courseAccuracyDegrees: sample.courseAccuracyDegrees,
                barometricAltitudeMeters: sample.barometricAltitudeMeters,
                deviceHeadingDegrees: sample.deviceHeadingDegrees,
                deviceHeadingAccuracyDegrees: sample.deviceHeadingAccuracyDegrees
            )
        })
    }

    private func payload(_ payload: RecordedFlightEventPayload) -> FlightEvidenceBundleV1.EventPayload {
        typealias Value = PortableValue
        switch payload {
        case .recordingStarted(let cause):
            return .init(kind: "recordingStarted", values: ["cause": .string(recordingStartCause(cause))])
        case .legStarted(let legID):
            return .init(kind: "legStarted", values: ["legIdentifier": .identifier(legID)])
        case .destinationIdentified(let legID):
            return .init(kind: "destinationIdentified", values: ["legIdentifier": .identifier(legID)])
        case .identificationPointReached(let key):
            return .init(kind: "identificationPointReached", values: [
                "legIdentifier": .identifier(key.legID),
                "identificationPointIdentifier": .identifier(key.identificationPointID),
            ])
        case .waypointReached(let legID):
            return .init(kind: "waypointReached", values: ["legIdentifier": .identifier(legID)])
        case .automaticNextLegTransition(let fromLegID, let toLegID):
            return .init(kind: "automaticNextLegTransition", values: [
                "fromLegIdentifier": .identifier(fromLegID),
                "toLegIdentifier": .identifier(toLegID),
            ])
        case .finalWaypointReached(let legID):
            return .init(kind: "finalWaypointReached", values: ["legIdentifier": .identifier(legID)])
        case .automaticLegRecovery(let legID):
            return .init(kind: "automaticLegRecovery", values: ["legIdentifier": .identifier(legID)])
        case .etaRevised(let target, let priorSeconds, let committedSeconds):
            var values: [String: Value] = [
                "legIdentifier": .identifier(target.legID),
                "targetKind": .string(timingTargetKind(target.kind)),
                "targetIdentifier": .identifier(target.targetID),
                "committedSeconds": .integer(Int64(committedSeconds)),
            ]
            if let priorSeconds {
                values["priorSeconds"] = .integer(Int64(priorSeconds))
            }
            return .init(kind: "etaRevised", values: values)
        case .headingRevised(let legID, let priorDegrees, let committedDegrees):
            return .init(kind: "headingRevised", values: [
                "legIdentifier": .identifier(legID),
                "priorDegrees": .integer(Int64(priorDegrees)),
                "committedDegrees": .integer(Int64(committedDegrees)),
            ])
        case .reachUndone(let originalEventID):
            return .init(kind: "reachUndone", values: ["originalEventIdentifier": .identifier(originalEventID)])
        case .positionCheckRequested:
            return .init(kind: "positionCheckRequested")
        case .positionCheckEnded(let outcome):
            switch outcome {
            case .endedWithoutDisclosure:
                return .init(kind: "positionCheckEnded", values: ["outcome": .string("endedWithoutDisclosure")])
            case .disclosed(let sample):
                return .init(kind: "positionCheckEnded", values: [
                    "outcome": .string("disclosed"),
                    "sample": .object([
                        "latitudeDegrees": .number(sample.coordinate.latitudeDegrees),
                        "longitudeDegrees": .number(sample.coordinate.longitudeDegrees),
                        "observedAt": .timestamp(sample.observedAt),
                        "horizontalAccuracyMeters": .number(sample.horizontalAccuracyMeters),
                    ]),
                ])
            }
        case .storageDegraded(let reason):
            return .init(kind: "storageDegraded", values: ["reason": .string(reason.rawValue)])
        case .locationAvailabilityChanged(let availability):
            return .init(kind: "locationAvailabilityChanged", values: ["availability": .string(availability.rawValue)])
        case .physicalStateChanged(let from, let to):
            return .init(kind: "physicalStateChanged", values: [
                "from": .string(physicalState(from)),
                "to": .string(physicalState(to)),
            ])
        case .physicalStateCorrected(let originalEventID, let from, let to):
            return .init(kind: "physicalStateCorrected", values: [
                "originalEventIdentifier": .identifier(originalEventID),
                "from": .string(physicalState(from)),
                "to": .string(physicalState(to)),
            ])
        case .navigationCompleted:
            return .init(kind: "navigationCompleted")
        case .recoveryContinued:
            return .init(kind: "recoveryContinued")
        case .manualEnd:
            return .init(kind: "manualEnd")
        case .recordingClosed(let outcome, let cause):
            return .init(kind: "recordingClosed", values: [
                "outcome": .string(outcome == .complete ? "complete" : "incomplete"),
                "cause": .string(closureCause(cause)),
            ])
        }
    }

    private func nanoseconds(_ duration: Duration) throws -> Int64 {
        let components = duration.components
        let (seconds, secondsOverflow) = components.seconds.multipliedReportingOverflow(by: 1_000_000_000)
        let attoseconds = components.attoseconds / 1_000_000_000
        let (value, additionOverflow) = seconds.addingReportingOverflow(attoseconds)
        guard !secondsOverflow, !additionOverflow else {
            throw FlightEvidenceMappingError.durationOutOfRange
        }
        return value
    }

    private func detectorPolicyContext(
        _ snapshot: PhysicalFlightDetectionPolicySnapshot
    ) -> FlightEvidenceBundleV1.DetectorPolicyContext {
        let policy = snapshot.policy
        return .init(version: snapshot.version, values: [
            "maximumHorizontalAccuracyMeters": .number(policy.maximumHorizontalAccuracyMeters),
            "maximumSpeedAccuracyMetersPerSecond": .number(policy.maximumSpeedAccuracyMetersPerSecond),
            "groundMovementSpeedMetersPerSecond": .number(policy.groundMovementSpeedMetersPerSecond),
            "groundMovementWindowSeconds": .number(seconds(policy.groundMovementWindow)),
            "candidateInterruptionToleranceSeconds": .number(seconds(policy.candidateInterruptionTolerance)),
            "takeoffSpeedMetersPerSecond": .number(policy.takeoffSpeedMetersPerSecond),
            "takeoffAltitudeGainMeters": .number(policy.takeoffAltitudeGainMeters),
            "takeoffWindowSeconds": .number(seconds(policy.takeoffWindow)),
            "landingSpeedMetersPerSecond": .number(policy.landingSpeedMetersPerSecond),
            "landingAltitudeToleranceMeters": .number(policy.landingAltitudeToleranceMeters),
            "landingWindowSeconds": .number(seconds(policy.landingWindow)),
            "stoppedSpeedMetersPerSecond": .number(policy.stoppedSpeedMetersPerSecond),
            "stoppedWindowSeconds": .number(seconds(policy.stoppedWindow)),
            "provisionalTimeoutSeconds": .number(seconds(policy.provisionalTimeout)),
            "airborneLaunchWindowSeconds": .number(seconds(policy.airborneLaunchWindow)),
        ])
    }

    private func seconds(_ duration: Duration) -> Double {
        let components = duration.components
        return Double(components.seconds) + Double(components.attoseconds) / 1e18
    }

    private func timingTargetKind(_ kind: NavigationTimingTargetKey.Kind) -> String {
        switch kind {
        case .identificationPoint: "identificationPoint"
        case .destination: "destination"
        }
    }

    private func recordingStartCause(_ cause: RecordedFlightEventPayload.RecordingStartCause) -> String {
        switch cause {
        case .startLegWithoutLocation: "startLegWithoutLocation"
        case .automaticTakeoff: "automaticTakeoff"
        case .partialStart: "partialStart"
        }
    }

    private func physicalState(_ state: PhysicalFlightState) -> String {
        state.rawValue
    }

    private func navigationState(_ state: RecordedNavigationState) -> String {
        switch state {
        case .ready: "ready"
        case .active: "active"
        case .reachedFinalWaypoint: "reachedFinalWaypoint"
        case .complete: "complete"
        }
    }

    private func gpsCoverage(_ coverage: GPSCoverageState) -> String {
        switch coverage {
        case .available: "available"
        case .partial: "partial"
        case .unavailable: "unavailable"
        }
    }

    private func closureCause(_ cause: FlightRecordingClosure.Cause) -> String {
        switch cause {
        case .automatic: "automatic"
        case .manual: "manual"
        case .recoveryExpired: "recoveryExpired"
        case .endedDuringRecovery: "endedDuringRecovery"
        case .supersededDuringRecovery: "supersededDuringRecovery"
        }
    }
}
