import Foundation

nonisolated struct FlightRecordingEvidenceSummary: Codable, Equatable, Sendable {
    let distanceMeters: Double?
    let duration: Duration?
    let maximumAltitudeMeters: Double?
    let gpsCoverageFraction: Double?
}

nonisolated struct FlightRecordingSummaryProjector: Sendable {
    func project(snapshot: FlightRecordingReadSnapshot) -> FlightRecordingEvidenceSummary {
        let evidenceEnd = snapshot.recording.closure?.closedAt
            ?? (snapshot.events.map(\.occurredAt) + snapshot.trackSegments.flatMap(\.samples).map(\.observedAt)).max()
        return project(
            trackSegments: snapshot.trackSegments,
            startedAt: snapshot.recording.startedAt,
            endedAt: evidenceEnd,
            knownGapIntervals: Self.knownGapIntervals(
                events: snapshot.events,
                endedAt: evidenceEnd
            )
        )
    }

    func project(
        trackSegments: [RecordedTrackSegment],
        startedAt: Date,
        endedAt: Date?,
        knownGapIntervals: [Range<Date>]
    ) -> FlightRecordingEvidenceSummary {
        let distances = trackSegments.flatMap { segment in
            zip(segment.samples, segment.samples.dropFirst()).map { from, to in
                Self.distance(from: from.coordinate, to: to.coordinate)
            }
        }
        let validAltitudes = trackSegments
            .flatMap(\.samples)
            .compactMap(\.altitudeMeters)
            .filter(\.isFinite)
        return FlightRecordingEvidenceSummary(
            distanceMeters: distances.isEmpty ? nil : distances.reduce(0, +),
            duration: endedAt.flatMap { end in
                let seconds = end.timeIntervalSince(startedAt)
                return seconds > 0 ? .seconds(seconds) : nil
            },
            maximumAltitudeMeters: validAltitudes.max(),
            gpsCoverageFraction: Self.coverage(
                startedAt: startedAt,
                endedAt: endedAt,
                gaps: knownGapIntervals,
                hasTrackEvidence: trackSegments.contains { !$0.samples.isEmpty }
            )
        )
    }

    private static func coverage(
        startedAt: Date,
        endedAt: Date?,
        gaps: [Range<Date>],
        hasTrackEvidence: Bool
    ) -> Double? {
        guard hasTrackEvidence || !gaps.isEmpty else { return nil }
        guard let endedAt else { return nil }
        let total = endedAt.timeIntervalSince(startedAt)
        guard total > 0 else { return nil }
        let clipped = gaps.compactMap { gap -> Range<Date>? in
            let lower = max(gap.lowerBound, startedAt)
            let upper = min(gap.upperBound, endedAt)
            return lower < upper ? lower..<upper : nil
        }.sorted { $0.lowerBound < $1.lowerBound }
        let merged = clipped.reduce(into: [Range<Date>]()) { result, gap in
            guard let last = result.last, gap.lowerBound <= last.upperBound else {
                result.append(gap)
                return
            }
            result[result.count - 1] = last.lowerBound..<max(last.upperBound, gap.upperBound)
        }
        let unavailable = merged.reduce(0) {
            $0 + $1.upperBound.timeIntervalSince($1.lowerBound)
        }
        return max(0, min(1, (total - unavailable) / total))
    }

    private static func knownGapIntervals(
        events: [RecordedFlightEvent],
        endedAt: Date?
    ) -> [Range<Date>] {
        var gapStart: Date?
        var gaps: [Range<Date>] = []
        for event in events.sorted(by: { $0.sequence < $1.sequence }) {
            guard case .locationAvailabilityChanged(let availability) = event.payload else { continue }
            switch availability {
            case .resumed:
                if let gapStart, gapStart < event.occurredAt {
                    gaps.append(gapStart..<event.occurredAt)
                }
                gapStart = nil
            case .servicesDisabled, .signalLost, .permissionDenied, .permissionRestricted:
                gapStart = gapStart ?? event.occurredAt
            }
        }
        if let gapStart, let endedAt, gapStart < endedAt {
            gaps.append(gapStart..<endedAt)
        }
        return gaps
    }

    private static func distance(
        from: WGS84Coordinate,
        to: WGS84Coordinate
    ) -> Double {
        let earthRadiusMeters = 6_371_000.0
        let latitude1 = from.latitudeDegrees * .pi / 180
        let latitude2 = to.latitudeDegrees * .pi / 180
        let latitudeDelta = (to.latitudeDegrees - from.latitudeDegrees) * .pi / 180
        let longitudeDelta = (to.longitudeDegrees - from.longitudeDegrees) * .pi / 180
        let haversine = pow(sin(latitudeDelta / 2), 2)
            + cos(latitude1) * cos(latitude2) * pow(sin(longitudeDelta / 2), 2)
        return earthRadiusMeters * 2 * atan2(sqrt(haversine), sqrt(1 - haversine))
    }
}
