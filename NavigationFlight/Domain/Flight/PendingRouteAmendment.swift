import Foundation

nonisolated struct PendingRouteAmendment: Codable, Equatable, Sendable {
    struct Stop: Codable, Equatable, Sendable {
        let id: UUID
        let name: String
        let latitude: Double
        let longitude: Double

        @MainActor
        init(id: UUID, name: String, position: WGS84Coordinate) {
            self.id = id
            self.name = name
            latitude = position.latitudeDegrees
            longitude = position.longitudeDegrees
        }

        @MainActor
        var position: WGS84Coordinate {
            WGS84Coordinate(latitudeDegrees: latitude, longitudeDegrees: longitude)
        }

        var isValid: Bool {
            !name.isEmpty && (-90...90).contains(latitude) && (-180...180).contains(longitude)
        }
    }

    struct Leg: Codable, Equatable, Sendable {
        let id: UUID
        let from: Stop
        let to: Stop
        let headingMagnetic: Int
        let durationSeconds: Int
        let altitudeFeet: Double?
        let frequencyMHz: Double?
        let visualReference: String?

        init(id: UUID, from: Stop, to: Stop, values: RouteAmendmentLegValues) {
            self.id = id
            self.from = from
            self.to = to
            headingMagnetic = values.headingMagnetic
            durationSeconds = values.durationSeconds
            altitudeFeet = values.altitude?.value
            frequencyMHz = values.frequency?.value
            visualReference = values.visualReference
        }

        var isValid: Bool {
            from.isValid && to.isValid && (1...360).contains(headingMagnetic) &&
                durationSeconds > 0 && altitudeFeet?.isFinite != false &&
                frequencyMHz.map { $0.isFinite && $0 > 0 } != false
        }
    }

    enum Validation: Error, Equatable, Sendable {
        case alreadyPending
        case invalidGeometry
        case unavailableDeparture
        case incompleteLegs
        case departureRequiresAmendmentActivation
    }

    let id: UUID
    let flightID: UUID
    let departure: RouteAmendmentAnchor
    let rejoin: RouteAmendmentAnchor
    let mode: RouteAmendmentMode
    let executionMode: NavigationMode
    let automaticProgression: Bool
    let replacementLegs: [Leg]
    let departurePlannedElapsedSeconds: Int?
    let retainedDeparturePointIDs: [UUID]

    var departureStop: Stop? { replacementLegs.first?.from }
    var departureIsPartway: Bool { departure.fraction > 0 && departure.fraction < 1 }

    func blocksArrival(at legIndex: Int) -> Bool {
        // A leg start that is not shared with the preceding arrival has no
        // corresponding destination action. Admission rejects that boundary.
        departure.legIndex == legIndex
    }

    @MainActor
    func includes(_ point: IdentificationPoint) -> Bool {
        !departureIsPartway || point.legID != departure.legID || point.progress.fraction < departure.fraction
    }

    @MainActor
    func includes(_ annotation: PlannedNavigationAnnotation, in plan: FlightPlan) -> Bool {
        guard let index = plan.legs.firstIndex(where: { $0.id == annotation.legID }) else { return false }
        if index != departure.legIndex { return index < departure.legIndex }
        if annotation.kind == .identificationPoint,
           let point = plan.identificationPoints.first(where: { $0.id == annotation.entityID }) {
            return includes(point)
        }
        guard let limit = departurePlannedElapsedSeconds else { return true }
        let time = executionMode == .wind ? annotation.withWindTimeFromLegStartSeconds : annotation.noWindTimeFromLegStartSeconds
        return time.map { $0 < limit } ?? false
    }

    @MainActor
    init(id: UUID, draft: RouteAmendmentDraft, flight: Flight, route: RouteAmendmentRoute) throws {
        guard flight.pendingRouteAmendment == nil else { throw Validation.alreadyPending }
        guard draft.flightID == flight.id, draft.step == .review, draft.legPanel == nil,
              let departure = draft.departure, let rejoin = draft.rejoin else { throw Validation.invalidGeometry }
        guard route.contains(departure), departure.legIndex >= flight.activeLegIndex,
              departure.fraction > 0,
              departure.legIndex != flight.activeLegIndex || departure.fraction > route.firstAvailable.fraction ||
                route.firstAvailable.legIndex < departure.legIndex else { throw Validation.unavailableDeparture }
        guard route.contains(rejoin), route.precedes(departure, rejoin) else { throw Validation.invalidGeometry }
        let reviewLegs = draft.reviewLegs(on: route)
        guard !reviewLegs.isEmpty, reviewLegs.allSatisfy({ $0.values != nil }) else { throw Validation.incompleteLegs }
        let partway = departure.fraction < 1
        let departureSource = route.legs[departure.legIndex].arrival
        let rejoinSource = route.legs[rejoin.legIndex]
        let first = Stop(
            id: partway ? UUID() : departureSource.id,
            name: partway ? String(localized: "Departure point") : departureSource.name,
            position: route.coordinate(at: departure)
        )
        let points = draft.points.enumerated().map { index, point in
            Stop(id: point.id, name: point.name ?? "Point \(index + 1)", position: point.position)
        }
        let last = Stop(
            id: rejoin.fraction == 0 ? rejoinSource.departure.id : rejoin.fraction == 1 ? rejoinSource.arrival.id : UUID(),
            name: route.name(for: rejoin),
            position: route.coordinate(at: rejoin)
        )
        let stops = [first] + points + [last]
        let legs = try zip(reviewLegs, zip(stops, stops.dropFirst())).map { review, endpoints in
            guard let values = review.values else { throw Validation.incompleteLegs }
            return Leg(id: UUID(), from: endpoints.0, to: endpoints.1, values: values)
        }
        let duration = route.originalLeg(departure.legID)?.durationSeconds
        guard !partway || duration.map({ $0 > 0 }) == true else { throw Validation.invalidGeometry }
        self.id = id
        flightID = flight.id
        self.departure = departure
        self.rejoin = rejoin
        mode = draft.mode
        executionMode = flight.executionMode
        automaticProgression = flight.progressionPolicy == .automaticNextLeg
        replacementLegs = legs
        departurePlannedElapsedSeconds = partway ? duration.map { max(1, Int((Double($0) * departure.fraction).rounded())) } : nil
        retainedDeparturePointIDs = route.identificationPoints.filter {
            $0.legID == departure.legID && (!partway || $0.progress.fraction < departure.fraction)
        }.map(\.id)
        try validate(flight: flight, route: route)
    }

    @MainActor
    func validate(flight: Flight, route: RouteAmendmentRoute) throws {
        guard flight.id == flightID, flight.executionMode == executionMode,
              (flight.progressionPolicy == .automaticNextLeg) == automaticProgression,
              flight.pendingRouteAmendment == nil else { throw Validation.invalidGeometry }
        guard route.contains(departure), departure.legIndex >= flight.activeLegIndex,
              departure.fraction > 0, route.precedes(route.firstAvailable, departure) else {
            throw Validation.unavailableDeparture
        }
        let retained = route.identificationPoints.filter { $0.legID == departure.legID && includes($0) }.map(\.id)
        guard retained == retainedDeparturePointIDs,
              route.contains(rejoin), route.precedes(departure, rejoin),
              let first = replacementLegs.first?.from, let last = replacementLegs.last?.to,
              route.sameLocation(first.position, route.coordinate(at: departure)),
              route.sameLocation(last.position, route.coordinate(at: rejoin)),
              Set(replacementLegs.map(\.id)).count == replacementLegs.count,
              Set(replacementLegs.map(\.id)).isDisjoint(with: flight.legIDs),
              replacementLegs.allSatisfy({ $0.isValid && !route.sameLocation($0.from.position, $0.to.position) }),
              zip(replacementLegs, replacementLegs.dropFirst()).allSatisfy({ $0.to == $1.from }) else {
            throw Validation.invalidGeometry
        }
        let source = route.legs[departure.legIndex]
        if departureIsPartway {
            guard !route.legs.contains(where: { $0.arrival.id == first.id || $0.departure.id == first.id }),
                  let planned = departurePlannedElapsedSeconds, planned > 0,
                  let original = route.originalLeg(source.id)?.durationSeconds,
                  planned == max(1, Int((Double(original) * departure.fraction).rounded())) else {
                throw Validation.invalidGeometry
            }
        } else if first.id != source.arrival.id || departurePlannedElapsedSeconds != nil {
            throw Validation.invalidGeometry
        }
    }
}
