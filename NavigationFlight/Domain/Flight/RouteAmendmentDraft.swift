import Foundation

struct RouteAmendmentAnchor: Hashable, Sendable {
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
        let fromY = mercatorY(from.latitudeDegrees)
        let y = fromY + (mercatorY(to.latitudeDegrees) - fromY) * fraction
        let longitude = from.longitudeDegrees + longitudeDelta(from.longitudeDegrees, to.longitudeDegrees) * fraction
        return WGS84Coordinate(
            latitudeDegrees: atan(sinh(y)) * 180 / .pi,
            longitudeDegrees: longitudeDelta(0, longitude)
        )
    }

    // The amendment overlay draws straight segments in Web Mercator.
    func fraction(on leg: NavigationLeg, at coordinate: WGS84Coordinate) -> Double {
        let from = leg.departure.position
        let to = leg.arrival.position
        let fromY = mercatorY(from.latitudeDegrees)
        let dx = longitudeDelta(from.longitudeDegrees, to.longitudeDegrees) * .pi / 180
        let dy = mercatorY(to.latitudeDegrees) - fromY
        let lengthSquared = dx * dx + dy * dy
        guard lengthSquared > 0 else { return 0 }
        let x = longitudeDelta(from.longitudeDegrees, coordinate.longitudeDegrees) * .pi / 180
        let y = mercatorY(coordinate.latitudeDegrees) - fromY
        return min(1, max(0, (x * dx + y * dy) / lengthSquared))
    }

    private func mercatorY(_ latitude: Double) -> Double {
        let limit = atan(sinh(Double.pi)) * 180 / .pi
        let radians = min(limit, max(-limit, latitude)) * .pi / 180
        return asinh(tan(radians))
    }

    private func longitudeDelta(_ from: Double, _ to: Double) -> Double {
        (to - from + 540).truncatingRemainder(dividingBy: 360) - 180
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
        guard !legTimings.isEmpty, legState != .completed, flightPlan.id == flightPlanID,
              flightPlan.legs.indices.contains(activeLegIndex),
              flightPlan.legs[activeLegIndex].id == legIDs[activeLegIndex] else { return nil }
        let leg = flightPlan.legs[activeLegIndex]
        let reportedProgress = flightPlan.identificationPoints
            .filter { $0.legID == leg.id }
            .filter { identificationPointTiming(for: .init(legID: leg.id, identificationPointID: $0.id))?.reachedAt != nil }
            .map(\.progress.fraction)
            .max() ?? 0
        let sharesPreviousBoundary = reportedProgress == 0 && activeLegIndex > 0 &&
            flightPlan.legs[activeLegIndex - 1].arrival.id == leg.departure.id
        let earliest = sharesPreviousBoundary
            ? RouteAmendmentAnchor(legIndex: activeLegIndex - 1, legID: flightPlan.legs[activeLegIndex - 1].id, fraction: 1)
            : RouteAmendmentAnchor(legIndex: activeLegIndex, legID: leg.id, fraction: reportedProgress)
        return RouteAmendmentRoute(legs: flightPlan.legs, firstAvailable: earliest)
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
        case plot(MapInput), chooseAnchor(RouteAmendmentAnchor), confirmRejoin
        case selectPoint(UUID), movePoint(UUID), removePoint(UUID)
        case undo, chooseDeparture, chooseRejoin, clearRejoin, back, review, finishHere
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

    let flightID: UUID
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
                sameLocation(last.position, route.coordinate(at: $0)) &&
                !sameLocation(previous, last.position)
        }
        .sorted(by: route.precedes)
    }

    var acceptsMapInput: Bool {
        switch step {
        case .departure, .drawing, .rejoin, .move: !isPaused
        default: false
        }
    }

    mutating func update(_ intent: Intent, route: RouteAmendmentRoute) {
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
        message = nil
        switch intent {
        case .plot(let input):
            guard acceptsMapInput else { return }
            if case .move(let id) = step {
                editPoint(id, replacingWith: input, route: route)
            } else if step == .departure || step == .rejoin {
                propose(input.anchors, route: route)
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
        case .selectPoint(let id):
            guard step == .drawing, points.contains(where: { $0.id == id }) else { return }
            sketch.selection = id
        case .movePoint(let id):
            guard step == .drawing, points.contains(where: { $0.id == id }) else { return }
            sketch.selection = id
            step = .move(id)
        case .removePoint(let id):
            guard step == .drawing, points.contains(where: { $0.id == id }) else { return }
            editPoint(id, replacingWith: nil, route: route)
        case .undo:
            guard step == .drawing || step == .departure, let previous = plotHistory.popLast() else { return }
            sketch = previous
            step = departure == nil ? .departure : .drawing
            validateDeparture(on: route)
        case .chooseDeparture:
            guard step == .staleDeparture || step == .drawing else { return }
            if step == .staleDeparture { sketch.departure = nil }
            step = .departure
        case .clearRejoin:
            guard step == .staleDeparture || step == .departure else { return }
            sketch.rejoin = nil
        case .chooseRejoin:
            guard step == .drawing else { return }
            step = .rejoin
        case .back:
            switch step {
            case .crossing(_, let purpose):
                switch purpose {
                case .departure: step = .departure
                case .rejoin: step = .rejoin
                case .finish: step = .drawing
                }
            case .departure where departure != nil: step = .drawing
            case .rejoin, .confirmRejoin, .move, .review: step = .drawing
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
        case .open, .pause, .resume, .discard: break
        }
    }

    func bypasses(_ anchor: RouteAmendmentAnchor, on route: RouteAmendmentRoute) -> Bool {
        guard let departure, let rejoin else { return false }
        return route.precedes(departure, anchor) && route.precedes(anchor, rejoin)
    }

    func segments(on route: RouteAmendmentRoute) -> [Segment] {
        let original = route.legs.indices.flatMap { index -> [Segment] in
            let leg = route.legs[index]
            guard let departure, let rejoin,
                  index >= departure.legIndex, index <= rejoin.legIndex else {
                return [Segment(from: leg.departure.position, to: leg.arrival.position, role: .retained)]
            }
            let start = index == departure.legIndex ? departure.fraction : 0
            let end = index == rejoin.legIndex ? rejoin.fraction : 1
            return [(0, start, Segment.Role.retained), (start, end, .bypassed), (end, 1, .retained)]
                .compactMap { from, to, role in
                    guard from < to else { return nil }
                    return Segment(from: route.coordinate(on: leg, at: from),
                                   to: route.coordinate(on: leg, at: to), role: role)
                }
        }
        let proposed = positions(in: sketch, on: route)
        return original + zip(proposed, proposed.dropFirst()).map {
            Segment(from: $0, to: $1, role: .proposed)
        }
    }

    private mutating func validateDeparture(on route: RouteAmendmentRoute) {
        if let departure, !route.contains(departure) {
            step = .staleDeparture
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
            step = .confirmRejoin(first)
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
        let coincident = candidates.filter {
            route.contains($0) && sameLocation(position, route.coordinate(at: $0)) && seen.insert($0).inserted
        }
        return Point(id: id, position: position, name: input.waypoint?.name, routeCandidates: coincident)
    }

    private func sameLocation(_ lhs: WGS84Coordinate, _ rhs: WGS84Coordinate) -> Bool {
        let longitudeDifference = abs(lhs.longitudeDegrees - rhs.longitudeDegrees)
        return abs(lhs.latitudeDegrees - rhs.latitudeDegrees) < 0.00000001 &&
            (longitudeDifference < 0.00000001 || abs(longitudeDifference - 360) < 0.00000001)
    }

    @discardableResult
    private mutating func applyPlot(_ candidate: Sketch, route: RouteAmendmentRoute) -> Bool {
        let coordinates = positions(in: candidate, on: route)
        guard !zip(coordinates, coordinates.dropFirst()).contains(where: { sameLocation($0, $1) }) else {
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
