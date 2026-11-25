import Foundation

nonisolated struct RouteAmendmentAnchor: Codable, Hashable, Sendable {
    let legIndex: Int
    let legID: UUID
    let fraction: Double
}

struct RouteAmendmentRoute: Equatable, Sendable {
    struct Stop: Identifiable, Equatable, Sendable {
        let id: RouteAmendmentAnchor
        let name: String
        let position: WGS84Coordinate
    }

    let legs: [NavigationLeg]
    let firstAvailable: RouteAmendmentAnchor
    let identificationPoints: [IdentificationPoint]

    struct OriginalLeg: Identifiable, Equatable, Sendable {
        let id: UUID
        let name: String
        let mode: NavigationMode
        let direction: Int?
        let durationSeconds: Int?
    }

    private let planning: [PlannedLegNavigation]
    private let amendmentLegs: [PendingRouteAmendment.Leg]
    private let navigationMode: NavigationMode

    func originalLeg(_ id: UUID) -> OriginalLeg? {
        guard let leg = legs.first(where: { $0.id == id }) else { return nil }
        if let amendment = amendmentLegs.first(where: { $0.id == id }) {
            return OriginalLeg(id: id, name: Self.legName(from: leg.departure.name, to: leg.arrival.name),
                               mode: navigationMode, direction: amendment.headingMagnetic,
                               durationSeconds: amendment.durationSeconds)
        }
        let plan = planning.first { $0.legID == id }
        let direction = navigationMode == .wind ? plan?.withWind?.magneticHeading : plan?.magneticCourse
        let duration = navigationMode == .wind ? plan?.withWind?.timing.durationSeconds : plan?.noWind.durationSeconds
        return OriginalLeg(id: id, name: Self.legName(from: leg.departure.name, to: leg.arrival.name), mode: navigationMode,
                           direction: direction.map { Int($0.value.rounded()) % 360 }, durationSeconds: duration)
    }

    static func legName(from departure: String, to arrival: String) -> String {
        "\u{2068}\(departure)\u{2069} → \u{2068}\(arrival)\u{2069}"
    }

    init(legs: [NavigationLeg], firstAvailable: RouteAmendmentAnchor,
         planning: [PlannedLegNavigation] = [], navigationMode: NavigationMode = .noWind,
         identificationPoints: [IdentificationPoint] = [], amendmentLegs: [PendingRouteAmendment.Leg] = []) {
        self.legs = legs
        self.firstAvailable = firstAvailable
        self.identificationPoints = identificationPoints
        self.planning = planning
        self.amendmentLegs = amendmentLegs
        self.navigationMode = navigationMode
    }

    func anchor(at index: Int, fraction: Double) -> RouteAmendmentAnchor {
        if fraction == 0, index > 0, legs[index - 1].arrival.id == legs[index].departure.id {
            return RouteAmendmentAnchor(legIndex: index - 1, legID: legs[index - 1].id, fraction: 1)
        }
        return RouteAmendmentAnchor(legIndex: index, legID: legs[index].id, fraction: fraction)
    }

    func precedes(_ lhs: RouteAmendmentAnchor, _ rhs: RouteAmendmentAnchor) -> Bool {
        (lhs.legIndex, lhs.fraction) < (rhs.legIndex, rhs.fraction)
    }

    func contains(_ anchor: RouteAmendmentAnchor) -> Bool {
        legs.indices.contains(anchor.legIndex) && legs[anchor.legIndex].id == anchor.legID &&
            (0...1).contains(anchor.fraction) && !precedes(anchor, firstAvailable)
    }

    func coordinate(at anchor: RouteAmendmentAnchor) -> WGS84Coordinate {
        coordinate(on: legs[anchor.legIndex], at: anchor.fraction)
    }

    func coordinate(on leg: NavigationLeg, at fraction: Double) -> WGS84Coordinate {
        let from = leg.departure.position
        let to = leg.arrival.position
        if fraction == 0 { return from }
        if fraction == 1 { return to }
        let fromY = Self.mercatorY(from.latitudeDegrees)
        let y = fromY + (Self.mercatorY(to.latitudeDegrees) - fromY) * fraction
        let longitude = from.longitudeDegrees + Self.longitudeDelta(from.longitudeDegrees, to.longitudeDegrees) * fraction
        return WGS84Coordinate(
            latitudeDegrees: atan(sinh(y)) * 180 / .pi,
            longitudeDegrees: Self.longitudeDelta(0, longitude)
        )
    }

    // The amendment overlay draws straight segments in Web Mercator.
    func fraction(on leg: NavigationLeg, at coordinate: WGS84Coordinate) -> Double {
        let from = leg.departure.position
        let to = leg.arrival.position
        let fromY = Self.mercatorY(from.latitudeDegrees)
        let dx = Self.longitudeDelta(from.longitudeDegrees, to.longitudeDegrees) * .pi / 180
        let dy = Self.mercatorY(to.latitudeDegrees) - fromY
        let lengthSquared = dx * dx + dy * dy
        guard lengthSquared > 0 else { return 0 }
        let x = Self.longitudeDelta(from.longitudeDegrees, coordinate.longitudeDegrees) * .pi / 180
        let y = Self.mercatorY(coordinate.latitudeDegrees) - fromY
        return min(1, max(0, (x * dx + y * dy) / lengthSquared))
    }

    nonisolated static func mercatorY(_ latitude: Double) -> Double {
        let limit = atan(sinh(Double.pi)) * 180 / .pi
        let radians = min(limit, max(-limit, latitude)) * .pi / 180
        return asinh(tan(radians))
    }

    nonisolated static func longitudeDelta(_ from: Double, _ to: Double) -> Double {
        (to - from + 540).truncatingRemainder(dividingBy: 360) - 180
    }

    func sameLocation(_ lhs: WGS84Coordinate, _ rhs: WGS84Coordinate) -> Bool {
        let longitudeDifference = abs(lhs.longitudeDegrees - rhs.longitudeDegrees)
        return abs(lhs.latitudeDegrees - rhs.latitudeDegrees) < 0.00000001 &&
            (longitudeDifference < 0.00000001 || abs(longitudeDifference - 360) < 0.00000001)
    }

    func coincidentAnchor(_ candidate: RouteAmendmentAnchor, at position: WGS84Coordinate) -> RouteAmendmentAnchor? {
        guard contains(candidate), sameLocation(position, coordinate(at: candidate)) else { return nil }
        // Conversion at a waypoint can produce an endpoint plus a fraction just inside it.
        let endpoints = [anchor(at: candidate.legIndex, fraction: 0), anchor(at: candidate.legIndex, fraction: 1)]
        return endpoints.first { contains($0) && sameLocation(position, coordinate(at: $0)) } ?? candidate
    }

    func name(for anchor: RouteAmendmentAnchor) -> String {
        let leg = legs[anchor.legIndex]
        switch anchor.fraction {
        case 0: return leg.departure.name
        case 1: return leg.arrival.name
        default: return "Leg \(anchor.legIndex + 1) · \(Int((anchor.fraction * 100).rounded()))%"
        }
    }

    func occurrence(for anchor: RouteAmendmentAnchor) -> String {
        let leg = legs[anchor.legIndex]
        return "Leg \(anchor.legIndex + 1) · \(leg.departure.name) → \(leg.arrival.name)"
    }

    func originalSegments(departure: RouteAmendmentAnchor?, rejoin: RouteAmendmentAnchor?) -> [RouteAmendmentDraft.Segment] {
        typealias Segment = RouteAmendmentDraft.Segment
        return legs.indices.flatMap { index -> [Segment] in
            let leg = legs[index]
            guard let departure, let rejoin,
                  index >= departure.legIndex, index <= rejoin.legIndex else {
                return [Segment(from: leg.departure.position, to: leg.arrival.position, role: .retained)]
            }
            let start = index == departure.legIndex ? departure.fraction : 0
            let end = index == rejoin.legIndex ? rejoin.fraction : 1
            return [(0, start, Segment.Role.retained), (start, end, .bypassed), (end, 1, .retained)]
                .compactMap { from, to, role in
                    guard from < to else { return nil }
                    return Segment(from: coordinate(on: leg, at: from),
                                   to: coordinate(on: leg, at: to), role: role)
                }
        }
    }

    var stops: [Stop] {
        var seen = Set<RouteAmendmentAnchor>()
        return legs.indices.flatMap { index in
            [anchor(at: index, fraction: 0), anchor(at: index, fraction: 1)]
        }.compactMap { anchor in
            guard seen.insert(anchor).inserted else { return nil }
            return Stop(id: anchor, name: name(for: anchor), position: coordinate(at: anchor))
        }
    }
}

extension Flight {
    func routeForAmendment(in flightPlan: FlightPlan) -> RouteAmendmentRoute? {
        guard !legTimings.isEmpty, legState != .completed, flightPlan.id == flightPlanID else { return nil }
        if let activation = activatedRouteAmendment {
            var sourceLegs = Array(flightPlan.legs.prefix(activation.replacementStartIndex))
            // A flown source leg may have ended at the actual departure instead of its imported destination.
            if let last = sourceLegs.last, last.id == activation.amendment.departure.legID,
               activation.amendment.departure.fraction < 1, let stop = activation.amendment.departureStop {
                let arrival = RouteWaypoint(
                    id: stop.id, name: stop.name, position: stop.position,
                    plannedAltitude: last.departure.plannedAltitude, generatedNumber: last.arrival.generatedNumber,
                    reportingPointReference: nil
                )
                sourceLegs[sourceLegs.count - 1] = .init(
                    id: last.id, departure: last.departure, arrival: arrival, windOverride: last.windOverride, remark: last.remark
                )
            }
            let amendmentLegs = activation.amendment.replacementLegs
            let replacementLegs = amendmentLegs.enumerated().map { offset, leg in
                let altitude = AltitudeFeet(value: leg.altitudeFeet ?? 0)
                @MainActor func waypoint(_ stop: PendingRouteAmendment.Stop, offset: Int) -> RouteWaypoint {
                    .init(id: stop.id, name: stop.name, position: stop.position, plannedAltitude: altitude,
                          generatedNumber: activation.replacementStartIndex + offset + 1, reportingPointReference: nil)
                }
                return NavigationLeg(id: leg.id, departure: waypoint(leg.from, offset: offset),
                                     arrival: waypoint(leg.to, offset: offset + 1), windOverride: nil, remark: nil)
            }
            let retainedPlan = retainedSourcePlan(flightPlan)
            let operationalIDs = legIDs
            let retainedLegs = (activation.retainedStartIndex..<operationalIDs.count).compactMap { index -> NavigationLeg? in
                guard let sourceIndex = sourceLegIndex(at: index), retainedPlan.legs.indices.contains(sourceIndex) else {
                    return nil
                }
                return retainedPlan.legs[sourceIndex]
            }
            let legs = sourceLegs + replacementLegs + retainedLegs
            guard legs.map(\.id) == operationalIDs else { return nil }
            return .init(
                legs: legs, firstAvailable: firstAmendableAnchor(in: legs, points: retainedPlan.identificationPoints),
                planning: retainedPlan.plannedNavigation.plannedNavigation?.legs ?? [],
                navigationMode: executionMode, identificationPoints: retainedPlan.identificationPoints,
                amendmentLegs: amendmentLegs
            )
        }
        guard flightPlan.legs.indices.contains(activeLegIndex),
              flightPlan.legs[activeLegIndex].id == activeLegID else { return nil }
        return RouteAmendmentRoute(
            legs: flightPlan.legs,
            firstAvailable: firstAmendableAnchor(in: flightPlan.legs, points: flightPlan.identificationPoints),
            planning: flightPlan.plannedNavigation.plannedNavigation?.legs ?? [],
            navigationMode: executionMode, identificationPoints: flightPlan.identificationPoints
        )
    }

    private func firstAmendableAnchor(in legs: [NavigationLeg], points: [IdentificationPoint]) -> RouteAmendmentAnchor {
        let leg = legs[activeLegIndex]
        let reportedProgress = points.lazy
            .filter { point in
                point.legID == leg.id && self.identificationPointTiming(
                    for: .init(legID: leg.id, identificationPointID: point.id)
                )?.reachedAt != nil
            }
            .map(\.progress.fraction)
            .max() ?? 0
        if reportedProgress == 0, activeLegIndex > 0,
           legs[activeLegIndex - 1].arrival.id == leg.departure.id {
            return .init(legIndex: activeLegIndex - 1, legID: legs[activeLegIndex - 1].id, fraction: 1)
        }
        return .init(legIndex: activeLegIndex, legID: leg.id, fraction: reportedProgress)
    }
}

struct RouteAmendmentDraft: Equatable, Sendable {
    struct Point: Identifiable, Equatable, Sendable {
        let id: UUID
        let position: WGS84Coordinate
        let name: String?
        let routeCandidates: [RouteAmendmentAnchor]
    }

    struct MapInput: Equatable, Sendable {
        let position: WGS84Coordinate
        var anchors: [RouteAmendmentAnchor] = []
        var waypoint: RouteAmendmentRoute.Stop?
        var pointID: UUID?
        var legHits: [LegChoice]?
        // A deliberate chart hit may snap to an original leg; map-center input does not.
        var isRouteTap = false
    }

    enum CrossingPurpose: Equatable, Sendable {
        case departure, rejoin, finish
    }

    enum Step: Equatable, Sendable {
        case departure
        case drawing
        case rejoin
        case crossing([RouteAmendmentAnchor], CrossingPurpose)
        case confirmRejoin(RouteAmendmentAnchor)
        case move(UUID)
        case staleDeparture
        case review
    }

    enum Intent {
        case open, pause, resume, discard
        case toggleWorkspace, togglePlotting, stopPlotting
        case resolveDrawingOverlap(rejoin: Bool)
        case plot(MapInput), chooseAnchor(RouteAmendmentAnchor), confirmRejoin
        case selectPoint(UUID), movePoint(UUID), removePoint(UUID)
        case undo, chooseDeparture, chooseRejoin, clearRejoin, back, review, finishHere
        case editLeg(ReviewLeg.ID), editLegField(RouteAmendmentLegEntry.Field, String)
        case saveLegValues, backToLegReview, checkLeg(ReviewLeg.ID)
        case toggleCues, toggleCheck, adjustHeading(Int), adjustFlightTime(Int)
        case inspectOriginal, cancelInspection, chooseLeg, selectLeg(LegChoice), closeLegPanel
    }

    struct Segment: Equatable, Sendable {
        enum Role: Equatable, Sendable { case retained, bypassed, proposed }
        let from: WGS84Coordinate
        let to: WGS84Coordinate
        let role: Role
    }

    private struct Sketch: Equatable, Sendable {
        var departure: RouteAmendmentAnchor?
        var points: [Point] = []
        var rejoin: RouteAmendmentAnchor?
        var selection: UUID?
    }

    struct ReviewLeg: Identifiable, Equatable, Sendable {
        enum Endpoint: Hashable, Sendable {
            case anchor(RouteAmendmentAnchor)
            case point(UUID)
        }

        struct ID: Hashable, Sendable {
            let from: Endpoint
            let to: Endpoint
        }

        let id: ID
        let departureName: String
        let arrivalName: String
        let from: WGS84Coordinate
        let to: WGS84Coordinate
        let entry: RouteAmendmentLegEntry

        // Complete values remain the compatibility boundary for final route validation.
        var values: RouteAmendmentLegValues? { entry.values }

        // Geometry validates saved values separately from the leg's logical identity.
        fileprivate var geometry: LegGeometry {
            .init(id: id, fromLatitude: from.latitudeDegrees, fromLongitude: from.longitudeDegrees,
                  toLatitude: to.latitudeDegrees, toLongitude: to.longitudeDegrees)
        }
    }

    fileprivate struct LegGeometry: Hashable, Sendable {
        let id: ReviewLeg.ID
        let fromLatitude: Double
        let fromLongitude: Double
        let toLatitude: Double
        let toLongitude: Double
    }

    enum LegChoice: Hashable, Sendable {
        case original(UUID)
        case proposed(ReviewLeg.ID)
    }

    struct LegChoiceRow: Identifiable {
        let id: LegChoice
        let name: String
        let legNumber: Int

        var isProposed: Bool {
            if case .proposed = id { return true }
            return false
        }
    }

    struct Editor: Equatable, Sendable {
        let id: ReviewLeg.ID
        var entry: RouteAmendmentLegEntry
        var showValidation = false
        var showsCues = false
        var estimate: RouteAmendmentEstimator.Result?
        var referenceID: UUID?
    }

    enum LegPanel: Equatable, Sendable {
        case editor
        case drawingOverlap([LegChoice], [RouteAmendmentAnchor])
        case inspection
        case chooser([LegChoice], inspecting: Bool, overlap: Bool)
        case original(UUID, inspecting: Bool)
    }

    let flightID: UUID
    let mode: RouteAmendmentMode
    private(set) var editor: Editor?
    private(set) var legPanel: LegPanel?
    private(set) var overlapPosition: WGS84Coordinate?

    var isInspecting: Bool {
        if case .inspection = legPanel { return true }
        return false
    }

    var isChoosingInspectionLeg: Bool {
        if case .chooser(_, true, _) = legPanel { return true }
        return false
    }

    var acceptsLegTap: Bool {
        !isPaused && (isInspecting || ((step == .drawing || step == .review) && legPanel == nil))
    }

    func legChoices(on route: RouteAmendmentRoute, originalsOnly: Bool) -> [LegChoice] {
        let originals = route.legs.map { LegChoice.original($0.id) }
        return originalsOnly ? originals : originals + reviewLegs(on: route).map { .proposed($0.id) }
    }

    func legChoiceRows(_ choices: [LegChoice], on route: RouteAmendmentRoute) -> [LegChoiceRow] {
        let proposed = reviewLegs(on: route)
        let rows = choices.compactMap { choice -> LegChoiceRow? in
            switch choice {
            case .original(let id):
                guard let index = route.legs.firstIndex(where: { $0.id == id }),
                      let original = route.originalLeg(id) else { return nil }
                return .init(id: choice, name: original.name, legNumber: index + 1)
            case .proposed(let id):
                guard let index = proposed.firstIndex(where: { $0.id == id }) else { return nil }
                let leg = proposed[index]
                let name = RouteAmendmentRoute.legName(from: leg.departureName, to: leg.arrivalName)
                return .init(id: choice, name: name, legNumber: index + 1)
            }
        }
        let groupedByRole = Dictionary(grouping: rows, by: \.isProposed)
        let groupedByName = groupedByRole.mapValues { Dictionary(grouping: $0, by: \.name) }
        return rows.map { row in
            guard (groupedByName[row.isProposed]?[row.name]?.count ?? 0) > 1 else { return row }
            return .init(id: row.id, name: "Leg \(row.legNumber) · \(row.name)", legNumber: row.legNumber)
        }
    }

    func selectedLegEndpoints(on route: RouteAmendmentRoute) -> (WGS84Coordinate, WGS84Coordinate)? {
        switch legPanel {
        case .editor:
            guard let id = editor?.id, let leg = reviewLegs(on: route).first(where: { $0.id == id }) else { return nil }
            return (leg.from, leg.to)
        case .original(let id, _):
            guard let leg = route.legs.first(where: { $0.id == id }) else { return nil }
            return (leg.departure.position, leg.arrival.position)
        default:
            return nil
        }
    }

    private var legEntries: [LegGeometry: RouteAmendmentLegEntry] = [:]

    init(flightID: UUID, mode: RouteAmendmentMode = .manual) {
        self.flightID = flightID
        self.mode = mode
    }

    init(replacing amendment: PendingRouteAmendment, on route: RouteAmendmentRoute) {
        self.init(flightID: amendment.flightID, mode: amendment.mode)
        sketch.departure = amendment.departure
        sketch.rejoin = amendment.rejoin
        sketch.points = amendment.replacementLegs.dropLast().map { leg in
            Point(id: leg.to.id, position: leg.to.position, name: leg.to.name, routeCandidates: [])
        }
        step = .review
        for (review, saved) in zip(reviewLegs(on: route), amendment.replacementLegs) {
            legEntries[review.geometry] = RouteAmendmentLegEntry(values: RouteAmendmentLegValues(
                headingMagnetic: saved.headingMagnetic, durationSeconds: saved.durationSeconds,
                altitude: saved.altitudeFeet.map(AltitudeFeet.init(value:)),
                frequency: saved.frequencyMHz.map(FrequencyMHz.init(value:)),
                visualReference: saved.visualReference
            ))
        }
        validateDeparture(on: route)
    }

    func reviewLegs(on route: RouteAmendmentRoute) -> [ReviewLeg] {
        guard let departure else { return [] }
        typealias Stop = (id: ReviewLeg.Endpoint, name: String, position: WGS84Coordinate)
        func stop(_ anchor: RouteAmendmentAnchor) -> Stop {
            (.anchor(anchor), route.name(for: anchor), route.coordinate(at: anchor))
        }
        let via: [Stop] = points.enumerated().map { index, point in
            (.point(point.id),
             point.name ?? "Point \(index + 1)", point.position)
        }
        let stops = [stop(departure)] + via + (rejoin.map { [stop($0)] } ?? [])
        return zip(stops, stops.dropFirst()).map { from, to in
            let id = ReviewLeg.ID(from: from.id, to: to.id)
            let geometry = LegGeometry(id: id, fromLatitude: from.position.latitudeDegrees,
                                       fromLongitude: from.position.longitudeDegrees,
                                       toLatitude: to.position.latitudeDegrees, toLongitude: to.position.longitudeDegrees)
            return ReviewLeg(id: id, departureName: from.name, arrivalName: to.name,
                             from: from.position, to: to.position, entry: legEntries[geometry] ?? .init())
        }
    }
    private var sketch = Sketch()
    private var plotHistory: [Sketch] = []
    private(set) var step: Step = .departure
    private(set) var isPaused = false
    private(set) var message: String?

    var departure: RouteAmendmentAnchor? { sketch.departure }
    var rejoin: RouteAmendmentAnchor? { sketch.rejoin }
    var points: [Point] { sketch.points }
    var selectedPointID: UUID? { sketch.selection }
    var hasContent: Bool { departure != nil || !points.isEmpty || rejoin != nil }
    var canUndo: Bool { !plotHistory.isEmpty }
    var canReview: Bool { departure != nil && rejoin != nil && step == .drawing }

    func availableStops(on route: RouteAmendmentRoute) -> [RouteAmendmentRoute.Stop] {
        guard step == .departure || step == .rejoin else { return route.stops }
        return route.stops.filter { isValid($0.id, forDeparture: step == .departure, route: route) }
    }

    func finishCandidates(on route: RouteAmendmentRoute) -> [RouteAmendmentAnchor] {
        guard rejoin == nil, let last = points.last, let departure, route.contains(departure) else { return [] }
        let previous = points.dropLast().last?.position ?? route.coordinate(at: departure)
        return last.routeCandidates.filter {
            isValid($0, forDeparture: false, route: route) &&
                route.sameLocation(last.position, route.coordinate(at: $0)) &&
                !route.sameLocation(previous, last.position)
        }
        .sorted(by: route.precedes)
    }

    var acceptsMapInput: Bool {
        switch step {
        case .departure, .drawing, .rejoin, .move: !isPaused && legPanel == nil
        default: false
        }
    }

    mutating func update(
        _ intent: Intent, route: RouteAmendmentRoute, estimateInputs: RouteAmendmentEstimator.Inputs? = nil
    ) {
        switch intent {
        case .pause:
            isPaused = true
            return
        case .resume, .open:
            isPaused = false
            validateDeparture(on: route)
            return
        default:
            guard !isPaused else { return }
        }

        validateDeparture(on: route)
        if legPanel != nil {
            switch intent {
            case .resolveDrawingOverlap, .plot, .inspectOriginal, .cancelInspection, .chooseLeg, .selectLeg, .closeLegPanel,
                 .editLegField, .saveLegValues, .backToLegReview, .toggleCues, .toggleCheck,
                 .adjustHeading, .adjustFlightTime: break
            default: return
            }
        }
        message = nil
        switch intent {
        case .stopPlotting:
            guard step != .staleDeparture else { return }
            step = departure == nil ? .departure : reviewLegs(on: route).isEmpty ? .drawing : .review
        case .plot(let input):
            if let hits = input.legHits, acceptsLegTap {
                let eligible = legChoices(on: route, originalsOnly: isInspecting)
                let choices = eligible.filter { hits.contains($0) }.filter {
                    if isInspecting { return true }
                    if case .proposed = $0 { return true }
                    return false
                }
                let anchors = rejoinCandidates(from: input, on: route)
                    .filter { isValid($0, forDeparture: false, route: route) }
                if !isInspecting, departure != nil, rejoin == nil, !choices.isEmpty, !anchors.isEmpty {
                    legPanel = .drawingOverlap(choices, anchors)
                    return
                }
                if choices.count > 1 {
                    overlapPosition = input.position
                    legPanel = .chooser(choices, inspecting: isInspecting, overlap: true)
                    return
                } else if let choice = choices.first {
                    selectLeg(choice, inspecting: isInspecting, on: route)
                    return
                } else if isInspecting {
                    message = "No original leg here. Try another chart location."
                    return
                }
            }
            guard acceptsMapInput else { return }
            if case .move(let id) = step {
                editPoint(id, replacingWith: input, route: route)
            } else if step == .departure || step == .rejoin {
                propose(input.anchors, route: route)
            } else if rejoin != nil {
                return
            } else if !rejoinCandidates(from: input, on: route).isEmpty {
                propose(rejoinCandidates(from: input, on: route), route: route)
            } else if let id = input.pointID, points.contains(where: { $0.id == id }) {
                sketch.selection = id
            } else {
                let point = plottedPoint(from: input, on: route)
                var candidate = sketch
                candidate.points.append(point)
                candidate.selection = point.id
                applyPlot(candidate, route: route)
            }
        case .chooseAnchor(let anchor):
            if case .crossing(let options, let purpose) = step {
                guard options.contains(anchor) else { return }
                if purpose == .finish {
                    guard finishCandidates(on: route).contains(anchor) else { return }
                    finish(at: anchor, on: route)
                    return
                }
                let choosingDeparture = purpose == .departure
                guard isValid(anchor, forDeparture: choosingDeparture, route: route) else {
                    message = choosingDeparture ? "Choose a departure on the remaining route before rejoin."
                        : "Choose a return point ahead of departure."
                    return
                }
                step = choosingDeparture ? .departure : .rejoin
            }
            guard step == .departure || step == .rejoin else { return }
            propose([anchor], route: route)
        case .confirmRejoin:
            guard case .confirmRejoin(let anchor) = step else { return }
            var candidate = sketch
            candidate.rejoin = anchor
            if applyPlot(candidate, route: route) { step = .drawing }
        case .resolveDrawingOverlap(let shouldRejoin):
            guard case .drawingOverlap(let choices, let anchors) = legPanel else { return }
            legPanel = nil
            guard departure != nil, rejoin == nil, step == .drawing else { return }
            if shouldRejoin {
                // Re-resolve against current progress rather than trusting the displayed options.
                propose(anchors.filter { isValid($0, forDeparture: false, route: route) }, route: route)
            } else if choices.count == 1, let choice = choices.first {
                selectLeg(choice, inspecting: false, on: route)
            } else {
                legPanel = .chooser(choices, inspecting: false, overlap: true)
            }
        case .selectPoint(let id):
            guard step == .drawing || step == .review, points.contains(where: { $0.id == id }) else { return }
            sketch.selection = id
        case .movePoint(let id):
            guard step == .drawing || step == .review, points.contains(where: { $0.id == id }) else { return }
            sketch.selection = id
            step = .move(id)
        case .removePoint(let id):
            guard step == .drawing || step == .review, points.contains(where: { $0.id == id }) else { return }
            editPoint(id, replacingWith: nil, route: route)
        case .undo:
            guard step == .drawing || step == .departure, let previous = plotHistory.popLast() else { return }
            sketch = previous
            step = departure == nil ? .departure : .drawing
            validateDeparture(on: route)
        case .chooseDeparture:
            guard step == .staleDeparture || step == .drawing || step == .review else { return }
            if step == .staleDeparture { sketch.departure = nil }
            step = .departure
        case .clearRejoin:
            guard step == .staleDeparture || step == .departure else { return }
            sketch.rejoin = nil
        case .chooseRejoin:
            guard step == .drawing || step == .review else { return }
            var candidate = sketch
            candidate.rejoin = nil
            guard applyPlot(candidate, route: route) else { return }
            step = .rejoin
        case .back:
            switch step {
            case .crossing(_, let purpose):
                switch purpose {
                case .departure: step = .departure
                case .rejoin: step = .drawing
                case .finish: step = .drawing
                }
            case .departure where departure != nil: step = .drawing
            case .review:
                editor = nil
                legPanel = nil
                step = .drawing
            case .rejoin, .confirmRejoin, .move: step = .drawing
            default: break
            }
        case .review:
            guard canReview else { return }
            step = .review
        case .finishHere:
            guard step == .drawing else { return }
            let candidates = finishCandidates(on: route)
            guard let anchor = candidates.first else { return }
            if candidates.count == 1 {
                finish(at: anchor, on: route)
            } else {
                step = .crossing(candidates, .finish)
            }
        case .editLeg(let id):
            openEditor(id, on: route)
        case .checkLeg(let id):
            openEditor(id, on: route, check: true, inputs: estimateInputs)
        case .editLegField(let field, let text):
            guard legPanel == .editor else { return }
            editor?.entry[field] = text
            retainEditorEntry(on: route)
        case .adjustHeading(let delta):
            guard legPanel == .editor else { return }
            editor?.entry.adjustHeading(by: delta)
            retainEditorEntry(on: route)
        case .adjustFlightTime(let delta):
            guard legPanel == .editor else { return }
            editor?.entry.adjustFlightTime(by: delta)
            retainEditorEntry(on: route)
        case .toggleCues:
            guard legPanel == .editor else { return }
            editor?.showsCues.toggle()
        case .toggleCheck:
            guard legPanel == .editor, let editor,
                  let leg = reviewLegs(on: route).first(where: { $0.id == editor.id }) else { return }
            let result = editor.estimate == nil ? estimate(for: leg, inputs: estimateInputs) : nil
            self.editor?.estimate = result
        case .saveLegValues:
            guard legPanel == .editor, let editor,
                  let leg = reviewLegs(on: route).first(where: { $0.id == editor.id }) else { return }
            // Exit preserves unfinished fields; only final-route validation requires completeness.
            legEntries[leg.geometry] = editor.entry
            self.editor = nil
            legPanel = nil
        case .backToLegReview:
            guard legPanel == .editor else { return }
            editor = nil
            legPanel = nil
        case .inspectOriginal:
            guard acceptsMapInput || legPanel == .editor else { return }
            legPanel = .inspection
        case .cancelInspection:
            guard isInspecting || isChoosingInspectionLeg else { return }
            overlapPosition = nil
            legPanel = editor == nil ? nil : .editor
        case .chooseLeg:
            guard acceptsLegTap || isChoosingInspectionLeg else { return }
            let inspecting = isInspecting || isChoosingInspectionLeg
            let originals = legChoices(on: route, originalsOnly: true)
            let proposed = inspecting ? [] : reviewLegs(on: route).map { LegChoice.proposed($0.id) }
            overlapPosition = nil
            legPanel = .chooser(proposed + originals, inspecting: inspecting, overlap: false)
        case .selectLeg(let choice):
            guard case .chooser(let choices, let inspecting, _) = legPanel, choices.contains(choice) else { return }
            selectLeg(choice, inspecting: inspecting, on: route)
        case .closeLegPanel:
            overlapPosition = nil
            switch legPanel {
            case .drawingOverlap:
                legPanel = nil
            case .inspection, .original:
                legPanel = editor == nil ? nil : .editor
            case .chooser(_, let inspecting, _):
                legPanel = inspecting ? .inspection : nil
            default: break
            }
        case .open, .pause, .resume, .discard, .toggleWorkspace, .togglePlotting: break
        }
    }

    private mutating func retainEditorEntry(on route: RouteAmendmentRoute) {
        guard let editor, let leg = reviewLegs(on: route).first(where: { $0.id == editor.id }) else { return }
        legEntries[leg.geometry] = editor.entry
    }

    private mutating func openEditor(
        _ id: ReviewLeg.ID, on route: RouteAmendmentRoute,
        check: Bool = false, inputs: RouteAmendmentEstimator.Inputs? = nil
    ) {
        guard legPanel == nil, step == .drawing || step == .review,
              let leg = reviewLegs(on: route).first(where: { $0.id == id }) else { return }
        let entry = leg.entry
        editor = Editor(id: id, entry: entry, estimate: check ? estimate(for: leg, inputs: inputs) : nil)
        legPanel = .editor
    }

    private func estimate(
        for leg: ReviewLeg, inputs: RouteAmendmentEstimator.Inputs?
    ) -> RouteAmendmentEstimator.Result {
        inputs.map { RouteAmendmentEstimator.estimate(from: leg.from, to: leg.to, inputs: $0) } ?? .unavailable
    }

    private mutating func selectLeg(_ choice: LegChoice, inspecting: Bool, on route: RouteAmendmentRoute) {
        overlapPosition = nil
        switch choice {
        case .original(let id):
            guard route.originalLeg(id) != nil else { return }
            if inspecting { editor?.referenceID = id }
            legPanel = .original(id, inspecting: inspecting)
        case .proposed(let id):
            guard !inspecting else { return }
            legPanel = nil
            openEditor(id, on: route)
        }
    }

    func bypasses(_ anchor: RouteAmendmentAnchor, on route: RouteAmendmentRoute) -> Bool {
        guard let departure, let rejoin else { return false }
        return route.precedes(departure, anchor) && route.precedes(anchor, rejoin)
    }

    func segments(on route: RouteAmendmentRoute) -> [Segment] {
        let original = route.originalSegments(departure: departure, rejoin: rejoin)
        let proposed = positions(in: sketch, on: route)
        return original + zip(proposed, proposed.dropFirst()).map {
            Segment(from: $0, to: $1, role: .proposed)
        }
    }

    mutating func requireNewDeparture() {
        step = .staleDeparture
        overlapPosition = nil
        editor = nil
        legPanel = nil
    }

    private mutating func validateDeparture(on route: RouteAmendmentRoute) {
        if let departure, !route.contains(departure) {
            step = .staleDeparture
            overlapPosition = nil
            editor = nil
            legPanel = nil
        }
    }

    private mutating func propose(_ anchors: [RouteAmendmentAnchor], route: RouteAmendmentRoute) {
        let choosingDeparture = step == .departure
        var seen = Set<RouteAmendmentAnchor>()
        let options = anchors.filter { route.contains($0) && seen.insert($0).inserted }
            .sorted(by: route.precedes)
        guard let first = options.first(where: { isValid($0, forDeparture: choosingDeparture, route: route) }) else {
            message = choosingDeparture ? "Choose a departure on the remaining route before rejoin."
                : "Choose a return point ahead of departure."
            return
        }
        if options.count > 1 {
            step = .crossing(options, choosingDeparture ? .departure : .rejoin)
        } else if choosingDeparture {
            var candidate = sketch
            candidate.departure = first
            if applyPlot(candidate, route: route) { step = .drawing }
        } else {
            var candidate = sketch
            candidate.rejoin = first
            if applyPlot(candidate, route: route) {
                step = .review
            }
        }
    }

    private func rejoinCandidates(from input: MapInput, on route: RouteAmendmentRoute) -> [RouteAmendmentAnchor] {
        let position = input.waypoint?.position ?? input.position
        var seen = Set<RouteAmendmentAnchor>()
        return (input.anchors + [input.waypoint?.id].compactMap { $0 }).compactMap { candidate in
            guard route.legs.indices.contains(candidate.legIndex),
                  route.legs[candidate.legIndex].id == candidate.legID,
                  (0...1).contains(candidate.fraction),
                  input.isRouteTap || route.sameLocation(position, route.coordinate(at: candidate)) else { return nil }
            let endpoints = [route.anchor(at: candidate.legIndex, fraction: 0),
                             route.anchor(at: candidate.legIndex, fraction: 1)]
            let anchor = endpoints.first { route.sameLocation(position, route.coordinate(at: $0)) } ?? candidate
            return seen.insert(anchor).inserted ? anchor : nil
        }
    }

    private func isValid(_ anchor: RouteAmendmentAnchor, forDeparture: Bool, route: RouteAmendmentRoute) -> Bool {
        guard route.contains(anchor) else { return false }
        if forDeparture {
            let limit = rejoin ?? route.anchor(at: route.legs.count - 1, fraction: 1)
            return route.precedes(anchor, limit)
        }
        return departure.map { route.precedes($0, anchor) } ?? false
    }

    private func positions(in sketch: Sketch, on route: RouteAmendmentRoute) -> [WGS84Coordinate] {
        [sketch.departure.map { route.coordinate(at: $0) }].compactMap { $0 } + sketch.points.map(\.position)
            + [sketch.rejoin.map { route.coordinate(at: $0) }].compactMap { $0 }
    }

    private mutating func finish(at anchor: RouteAmendmentAnchor, on route: RouteAmendmentRoute) {
        var candidate = sketch
        let endpoint = candidate.points.removeLast()
        candidate.rejoin = anchor
        if candidate.selection == endpoint.id { candidate.selection = nil }
        if applyPlot(candidate, route: route) { step = .review }
    }

    private func plottedPoint(from input: MapInput, on route: RouteAmendmentRoute, id: UUID = UUID()) -> Point {
        // A waypoint tap adopts that waypoint. Free plots keep their displayed location.
        let position = input.waypoint?.position ?? input.position
        let candidates = input.anchors + [input.waypoint?.id].compactMap { $0 }
        var seen = Set<RouteAmendmentAnchor>()
        let coincident = candidates.compactMap { candidate -> RouteAmendmentAnchor? in
            guard let anchor = route.coincidentAnchor(candidate, at: position),
                  seen.insert(anchor).inserted else { return nil }
            return anchor
        }
        return Point(id: id, position: position, name: input.waypoint?.name, routeCandidates: coincident)
    }

    @discardableResult
    private mutating func applyPlot(_ candidate: Sketch, route: RouteAmendmentRoute) -> Bool {
        let coordinates = positions(in: candidate, on: route)
        guard !zip(coordinates, coordinates.dropFirst()).contains(where: { route.sameLocation($0, $1) }) else {
            message = "Consecutive points must be at different locations."
            return false
        }
        guard candidate != sketch else { return true }
        plotHistory.append(sketch)
        sketch = candidate
        return true
    }

    private mutating func editPoint(_ id: UUID, replacingWith input: MapInput?, route: RouteAmendmentRoute) {
        guard let index = points.firstIndex(where: { $0.id == id }) else { return }
        var candidate = sketch
        if let input {
            candidate.points[index] = plottedPoint(from: input, on: route, id: id)
        } else {
            candidate.points.remove(at: index)
            candidate.selection = nil
        }
        if applyPlot(candidate, route: route) { step = .drawing }
    }
}
