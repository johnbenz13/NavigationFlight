import Foundation
import Testing
@testable import FlightEvidenceCore

@Suite("Diagnostic bundle codec")
struct DiagnosticBundleCodecTests {
    @Test("All portable evidence round-trips deterministically")
    func roundTrip() throws {
        let bundle = sampleBundle()
        let codec = DiagnosticBundleCodec()

        let first = try codec.encode(bundle)
        let decoded = try codec.decode(first)
        let second = try codec.encode(decoded)

        #expect(decoded == bundle)
        #expect(second == first)
        #expect(String(decoding: first, as: UTF8.self).contains(".123Z"))
    }

    @Test("Unsupported versions fail explicitly")
    func unsupportedVersion() throws {
        let bundle = sampleBundle(schemaVersion: 2)
        #expect(throws: DiagnosticBundleCodecError.unsupportedSchemaVersion(2)) {
            try DiagnosticBundleCodec().encode(bundle)
        }
    }

    @Test("Malformed event order fails explicitly")
    func invalidEventOrder() throws {
        let first = sampleEvent(sequence: 1)
        let second = sampleEvent(sequence: 1)
        let bundle = sampleBundle(events: [first, second])
        #expect(throws: DiagnosticBundleCodecError.invalidEventOrder) {
            try DiagnosticBundleCodec().encode(bundle)
        }
    }

    @Test("Negative accuracy values fail explicitly")
    func negativeAccuracy() throws {
        let bundle = sampleBundle(verticalAccuracyMeters: -1)
        #expect(throws: DiagnosticBundleCodecError.invalidMeasurement) {
            try DiagnosticBundleCodec().encode(bundle)
        }
    }

    @Test("Malformed event payload shapes fail explicitly")
    func malformedEventPayload() throws {
        let payload = FlightEvidenceBundleV1.EventPayload(
            kind: "waypointReached",
            values: ["legID": .identifier(UUID())]
        )
        let bundle = sampleBundle(events: [sampleEvent(sequence: 0, payload: payload)])
        #expect(throws: DiagnosticBundleCodecError.invalidEventPayload(kind: "waypointReached")) {
            try DiagnosticBundleCodec().encode(bundle)
        }
    }

    @Test("Out-of-order samples within a segment fail explicitly")
    func invalidSampleOrder() throws {
        let timestamp = Date(timeIntervalSince1970: 1_763_374_400.123)
        let bundle = sampleBundle(sampleObservedAts: [timestamp, timestamp.addingTimeInterval(-1)])
        #expect(throws: DiagnosticBundleCodecError.invalidMeasurement) {
            try DiagnosticBundleCodec().encode(bundle)
        }
    }

    private func sampleBundle(
        schemaVersion: Int = FlightEvidenceBundleV1.schemaVersion,
        events: [FlightEvidenceBundleV1.EventEvidence]? = nil,
        verticalAccuracyMeters: Double? = nil,
        sampleObservedAts: [Date]? = nil
    ) -> FlightEvidenceBundleV1 {
        let timestamp = Date(timeIntervalSince1970: 1_763_374_400.123)
        return FlightEvidenceBundleV1(
            schemaVersion: schemaVersion,
            bundleIdentifier: UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!,
            capturedAt: timestamp,
            sourceState: .closed,
            applicationContext: .init(appVersion: "1.0", appBuild: "1", platform: "iPadOS", osVersion: "27.0"),
            detectorPolicyContext: .init(version: "1", values: ["threshold": .number(42.5)]),
            recordingManifest: .init(
                recordingIdentifier: UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!,
                flightIdentifier: UUID(uuidString: "CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC")!,
                startedAt: timestamp,
                physicalState: "stopped",
                navigationState: "complete",
                gpsCoverage: "partial"
            ),
            flightPlan: .init(
                identifier: UUID(uuidString: "DDDDDDDD-DDDD-DDDD-DDDD-DDDDDDDDDDDD")!,
                title: "Synthetic flight",
                legIdentifiers: [UUID(uuidString: "EEEEEEEE-EEEE-EEEE-EEEE-EEEEEEEEEEEE")!],
                sourceData: Data([0, 1, 2, 255])
            ),
            closure: .init(
                outcome: "complete",
                cause: "automatic",
                closedAt: timestamp,
                elapsedNanoseconds: 10,
                landingEvidenceAvailable: true
            ),
            orderedEvents: events ?? [sampleEvent(sequence: 0)],
            trackSegments: [.init(
                identifier: UUID(uuidString: "FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF")!,
                samples: (sampleObservedAts ?? [timestamp]).map { observedAt in .init(
                    latitudeDegrees: 32.1,
                    longitudeDegrees: 34.8,
                    observedAt: observedAt,
                    horizontalAccuracyMeters: 4,
                    altitudeMeters: 123,
                    verticalAccuracyMeters: verticalAccuracyMeters,
                    groundSpeedMetersPerSecond: 45,
                    speedAccuracyMetersPerSecond: 1.5,
                    courseDegrees: 91,
                    courseAccuracyDegrees: 2,
                    barometricAltitudeMeters: 120,
                    deviceHeadingDegrees: nil,
                    deviceHeadingAccuracyDegrees: nil
                ) }
            )]
        )
    }

    private func sampleEvent(
        sequence: UInt64,
        payload: FlightEvidenceBundleV1.EventPayload? = nil
    ) -> FlightEvidenceBundleV1.EventEvidence {
        .init(
            identifier: UUID(),
            sequence: sequence,
            recordedAt: Date(timeIntervalSince1970: 1_763_374_400.123),
            elapsedNanoseconds: 10,
            origin: "pilot",
            payload: payload ?? .init(
                kind: "waypointReached",
                values: ["legIdentifier": .identifier(UUID())]
            )
        )
    }
}
