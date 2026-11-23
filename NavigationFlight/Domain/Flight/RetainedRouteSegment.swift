import Foundation

/// A separately timed suffix of one imported leg. The saved confirmation supplies
/// its identity and start occurrence. The immutable recording plan supplies its values.
struct RetainedRouteSegment {
    let legID: UUID
    let anchor: RouteAmendmentAnchor
    let start: PendingRouteAmendment.Stop

    init?(_ activation: ActivatedRouteAmendment?) {
        guard let activation, let legID = activation.splitLegID,
              let start = activation.amendment.replacementLegs.last?.to else { return nil }
        self.legID = legID
        self.anchor = activation.amendment.rejoin
        self.start = start
    }

    func includes(_ point: IdentificationPoint) -> Bool {
        point.legID == anchor.legID && point.progress.fraction > anchor.fraction
    }

    func project(_ plan: FlightPlan) -> FlightPlan {
        guard case .eligible(let navigation) = plan.plannedNavigation,
              plan.legs.indices.contains(anchor.legIndex),
              navigation.legs.indices.contains(anchor.legIndex) else { return plan }
        let source = plan.legs[anchor.legIndex]
        let resolved = navigation.legs[anchor.legIndex]
        let pointsByID = Dictionary(uniqueKeysWithValues: plan.identificationPoints.map { ($0.id, $0) })
        let altitudes = plan.altitudeChanges.filter { $0.legID == source.id }
        let altitudeProgress = Dictionary(uniqueKeysWithValues: altitudes.compactMap { change in
            progress(of: change.anchor, source: source, points: pointsByID).map { (change.id, $0) }
        })
        let effectiveAltitude = altitudes.filter { (altitudeProgress[$0.id] ?? .infinity) <= anchor.fraction }
            .enumerated().max {
                (altitudeProgress[$0.element.id] ?? 0, $0.offset) < (altitudeProgress[$1.element.id] ?? 0, $1.offset)
            }?.element.targetAltitude ?? resolved.initialAltitudeMsl

        let frequencies = plan.frequencyChanges.filter { $0.legID == source.id }
        let effectiveFrequency = frequencies.filter { $0.progress.fraction <= anchor.fraction }
            .enumerated().max { ($0.element.progress.fraction, $0.offset) < ($1.element.progress.fraction, $1.offset) }?.element
        let futureFrequencies = frequencies.filter { $0.progress.fraction > anchor.fraction }
        let retainedFrequencyIDs = Set(futureFrequencies.map(\.id) + [effectiveFrequency?.id].compactMap { $0 })
        let frequencyByID = Dictionary(uniqueKeysWithValues: frequencies.map { ($0.id, $0) })

        let departure = RouteWaypoint(
            id: start.id, name: start.name, position: start.position,
            plannedAltitude: effectiveAltitude, generatedNumber: source.departure.generatedNumber,
            reportingPointReference: nil
        )
        var legs = plan.legs
        legs[anchor.legIndex] = NavigationLeg(
            id: legID, departure: departure, arrival: source.arrival, windOverride: source.windOverride, remark: source.remark
        )
        var resolvedLegs = navigation.legs
        resolvedLegs[anchor.legIndex] = PlannedLegNavigation(
            legID: legID, trueCourse: resolved.trueCourse, magneticCourse: resolved.magneticCourse,
            groundDistance: .init(value: resolved.groundDistance.value * (1 - anchor.fraction)),
            initialAltitudeMsl: effectiveAltitude, noWind: timing(resolved.noWind),
            withWind: resolved.withWind.map {
                .init(timing: timing($0.timing), effectiveWind: $0.effectiveWind, trueHeading: $0.trueHeading,
                      magneticHeading: $0.magneticHeading, windCorrection: $0.windCorrection)
            }
        )
        let points = plan.identificationPoints.compactMap { point -> IdentificationPoint? in
            guard point.legID == source.id else { return point }
            guard includes(point) else { return nil }
            return .init(id: point.id, legID: legID, progress: rebase(point.progress.fraction),
                         lateralOffset: point.lateralOffset, timeLabelArrangement: point.timeLabelArrangement)
        }
        let altitudeChanges = plan.altitudeChanges.compactMap { change -> AltitudeChange? in
            guard change.legID == source.id else { return change }
            guard let fraction = altitudeProgress[change.id], fraction > anchor.fraction else { return nil }
            let retainedAnchor: AltitudeChangeAnchor = switch change.anchor {
            case .legProgress: .legProgress(rebase(fraction))
            case .waypoint, .identificationPoint: change.anchor
            }
            return .init(id: change.id, legID: legID, anchor: retainedAnchor, targetAltitude: change.targetAltitude,
                         symbolDirection: change.symbolDirection, showsAnchorMark: change.showsAnchorMark,
                         arrangement: change.arrangement)
        }
        let frequencyChanges = plan.frequencyChanges.compactMap { change -> FrequencyChange? in
            guard change.legID == source.id else { return change }
            guard retainedFrequencyIDs.contains(change.id) else { return nil }
            return .init(id: change.id, legID: legID, progress: rebase(change.progress.fraction),
                         service: change.service, frequency: change.frequency,
                         isFlippedHorizontally: change.isFlippedHorizontally, arrangement: change.arrangement)
        }
        let annotations = navigation.annotations.compactMap { annotation -> PlannedNavigationAnnotation? in
            guard annotation.legID == source.id else { return annotation }
            let progress: Double? = switch annotation.kind {
            case .identificationPoint: pointsByID[annotation.entityID]?.progress.fraction
            case .altitudeChange: altitudeProgress[annotation.entityID]
            case .radioFrequencyChange: frequencyByID[annotation.entityID]?.progress.fraction
            }
            let isBaseline = annotation.kind == .radioFrequencyChange && annotation.entityID == effectiveFrequency?.id
            guard let progress, isBaseline || progress > anchor.fraction else { return nil }
            // A forward cue that rounds to zero goes due on the first elapsed
            // second, after the original rejoin values have been presented.
            let minimumSeconds = annotation.kind == .identificationPoint ? 0 : 1
            func rebasedTime(_ timing: PlannedTiming) -> Int {
                guard !isBaseline else { return 0 }
                return max(minimumSeconds, Int((Double(timing.durationSeconds) * (progress - anchor.fraction)).rounded()))
            }
            return .init(
                entityID: annotation.entityID, kind: annotation.kind, legID: legID,
                position: isBaseline ? departure.position : annotation.position,
                noWindTimeFromLegStartSeconds: rebasedTime(resolved.noWind),
                withWindTimeFromLegStartSeconds: resolved.withWind.map { rebasedTime($0.timing) }
            )
        }
        let omittedFrequencies = Set(frequencies.map { "route:\($0.id.uuidString.lowercased())" })
            .subtracting(retainedFrequencyIDs.map { "route:\($0.uuidString.lowercased())" })
        return FlightPlan(
            id: plan.id, title: plan.title, createdAt: plan.createdAt, modifiedAt: plan.modifiedAt,
            parameters: plan.parameters, waypoints: plan.waypoints + [departure], legs: legs,
            identificationPoints: points, altitudeChanges: altitudeChanges, frequencyChanges: frequencyChanges,
            vorDmeReferences: plan.vorDmeReferences, operationalContext: plan.operationalContext,
            plannedNavigation: .eligible(.init(
                calculationVersion: navigation.calculationVersion, altitudeReference: navigation.altitudeReference,
                legs: resolvedLegs, annotations: annotations, vorDmeReferences: navigation.vorDmeReferences,
                frequenciesByPhase: navigation.frequenciesByPhase.mapValues { $0.filter { !omittedFrequencies.contains($0.id) } },
                defaultMode: navigation.defaultMode
            ))
        )
    }

    private func timing(_ source: PlannedTiming) -> PlannedTiming {
        .init(durationSeconds: max(1, Int((Double(source.durationSeconds) * (1 - anchor.fraction)).rounded())),
              groundSpeed: source.groundSpeed)
    }

    private func rebase(_ fraction: Double) -> LegProgress {
        .init(fraction: max(0, (fraction - anchor.fraction) / (1 - anchor.fraction)))
    }

    private func progress(
        of altitudeAnchor: AltitudeChangeAnchor, source: NavigationLeg, points: [UUID: IdentificationPoint]
    ) -> Double? {
        switch altitudeAnchor {
        case .legProgress(let progress): progress.fraction
        case .waypoint(let id): id == source.departure.id ? 0 : id == source.arrival.id ? 1 : nil
        case .identificationPoint(let id): points[id]?.progress.fraction
        }
    }
}
