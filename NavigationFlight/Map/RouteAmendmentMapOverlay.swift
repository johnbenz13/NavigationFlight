import MapLibre
import UIKit

final class RouteAmendmentMapOverlay: UIView {
    static let retainedColor = UIColor(red: 0, green: 0.43, blue: 0.80, alpha: 1)
    static let proposedColor = UIColor(red: 0, green: 0.42, blue: 0.41, alpha: 1)
    static let bypassedColor = UIColor(red: 0.39, green: 0.41, blue: 0.43, alpha: 1)

    struct Presentation: Equatable {
        let draft: RouteAmendmentDraft
        let route: RouteAmendmentRoute
        let isPlotting: Bool
    }

    struct Pending: Equatable {
        let amendment: PendingRouteAmendment
        let route: RouteAmendmentRoute
        let activePartwayDeparture: PendingRouteAmendment.Stop?
        let departureHeaderInset: CGFloat
        var isActivated = false
        var activeReplacementLegID: UUID? = nil
    }

    struct DepartureMarker {
        private static let diameter: CGFloat = 14
        private static let labelGap: CGFloat = 9
        private let label: NSAttributedString

        init(name: String, traits: UITraitCollection) {
            label = NSAttributedString(string: name, attributes: [
                .font: UIFontMetrics(forTextStyle: .caption1).scaledFont(
                    for: .systemFont(ofSize: 13, weight: .bold), compatibleWith: traits
                ),
                .foregroundColor: UIColor.black
            ])
        }

        var anchor: CGPoint {
            CGPoint(x: size.width / 2, y: badgeSize.height + Self.labelGap + Self.diameter / 2)
        }

        var size: CGSize {
            CGSize(width: max(44, badgeSize.width),
                   height: max(44, badgeSize.height + Self.labelGap + Self.diameter))
        }

        private var badgeSize: CGSize {
            let size = label.size()
            return CGSize(width: ceil(size.width) + 12, height: ceil(size.height) + 6)
        }

        func badgeRect(at point: CGPoint) -> CGRect {
            CGRect(x: point.x - badgeSize.width / 2,
                   y: point.y - Self.diameter / 2 - Self.labelGap - badgeSize.height,
                   width: badgeSize.width, height: badgeSize.height)
        }

        func draw(at point: CGPoint, color: UIColor, showsLabel: Bool, in context: CGContext) {
            let ring = CGRect(x: point.x - Self.diameter / 2, y: point.y - Self.diameter / 2,
                              width: Self.diameter, height: Self.diameter)
            context.setLineDash(phase: 0, lengths: [])
            context.setFillColor(UIColor.white.cgColor)
            context.fillEllipse(in: ring)
            context.setStrokeColor(color.cgColor)
            context.setLineWidth(2)
            context.strokeEllipse(in: ring.insetBy(dx: 1, dy: 1))
            guard showsLabel else { return }
            let badge = badgeRect(at: point)
            UIColor.white.setFill()
            UIBezierPath(roundedRect: badge, cornerRadius: 6).fill()
            label.draw(at: CGPoint(x: badge.minX + 6, y: badge.minY + 3))
        }
    }

    var showsPartwayDepartureLabel = true {
        didSet {
            if oldValue != showsPartwayDepartureLabel { setNeedsDisplay() }
        }
    }

    var pending: Pending? {
        didSet {
            guard oldValue != pending else { return }
            isHidden = presentation == nil && pending == nil
            setNeedsDisplay()
        }
    }

    var presentation: Presentation? {
        didSet {
            guard oldValue != presentation else { return }
            isHidden = presentation == nil && pending == nil
            setNeedsDisplay()
        }
    }

    weak var map: MLNMapView?
    var viewportDidLayout: (() -> Void)?

    override func layoutSubviews() {
        super.layoutSubviews()
        viewportDidLayout?()
    }

    init(map: MLNMapView) {
        self.map = map
        super.init(frame: map.bounds)
        autoresizingMask = [.flexibleWidth, .flexibleHeight]
        isUserInteractionEnabled = false
        accessibilityElementsHidden = true
        isOpaque = false
        isHidden = true
        contentMode = .redraw
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func input(at tap: CGPoint, placingAtCenter: Bool = false) -> RouteAmendmentDraft.MapInput? {
        guard let map, let presentation else { return nil }
        let coordinate = map.convert(tap, toCoordinateFrom: map)
        guard CLLocationCoordinate2DIsValid(coordinate) else { return nil }
        let position = WGS84Coordinate(latitudeDegrees: coordinate.latitude, longitudeDegrees: coordinate.longitude)
        guard presentation.draft.acceptsMapInput || presentation.draft.acceptsLegTap else { return nil }
        let isChoosingAnchor = presentation.draft.step == .departure || presentation.draft.step == .rejoin
        let retainsCenterPosition = placingAtCenter && !isChoosingAnchor

        let route = presentation.route
        let stopHits = route.stops.map { ($0, distance(tap, project($0.position, on: map))) }
            .filter { $0.1 <= 22 }.sorted { $0.1 < $1.1 }
        let pointID = retainsCenterPosition ? nil : presentation.draft.points
            .map { ($0.id, distance(tap, project($0.position, on: map))) }
            .filter { $0.1 <= 22 }.min { $0.1 < $1.1 }?.0
        func routeHits(near tap: CGPoint, snappingEndpoints: Bool) -> [(RouteAmendmentAnchor, CGFloat)] {
            route.legs.indices.compactMap { index -> (RouteAmendmentAnchor, CGFloat)? in
                let leg = route.legs[index]
                let from = project(leg.departure.position, on: map)
                let to = project(leg.arrival.position, on: map)
                let dx = to.x - from.x
                let dy = to.y - from.y
                let lengthSquared = dx * dx + dy * dy
                guard lengthSquared > 0 else { return nil }
                let screenFraction = max(0, min(1, ((tap.x - from.x) * dx + (tap.y - from.y) * dy) / lengthSquared))
                let snapped = CGPoint(x: from.x + dx * screenFraction, y: from.y + dy * screenFraction)
                let separation = distance(tap, snapped)
                guard separation <= 18 else { return nil }
                // Snap the endpoint occurrence before testing route order. The same coordinate
                // can still be an interior hit on a different leg crossing this waypoint.
                let endpoint = stopHits.map(\.0.id).first { anchor in
                    anchor == route.anchor(at: index, fraction: 0) || anchor == route.anchor(at: index, fraction: 1)
                }
                if snappingEndpoints, let endpoint { return (endpoint, separation) }
                let coordinate = map.convert(snapped, toCoordinateFrom: map)
                let position = WGS84Coordinate(latitudeDegrees: coordinate.latitude, longitudeDegrees: coordinate.longitude)
                return (route.anchor(at: index, fraction: route.fraction(on: leg, at: position)), separation)
            }
        }
        let tapLegHits = routeHits(near: tap, snappingEndpoints: !retainsCenterPosition)
        let nearest = min(stopHits.first?.1 ?? .infinity, tapLegHits.map(\.1).min() ?? .infinity)
        let nearbyLegs = tapLegHits.filter { $0.1 <= nearest + 7 }
        var anchors = stopHits.filter { $0.1 <= nearest + 7 }.map(\.0.id) + nearbyLegs.map(\.0)
        let waypoint = retainsCenterPosition ? nil : stopHits.first?.0
        if !isChoosingAnchor, let waypoint {
            // A named plot adopts the waypoint position. Test crossing legs there too.
            anchors += routeHits(near: project(waypoint.position, on: map), snappingEndpoints: false).map(\.0)
        }
        var plotPosition = position
        if !isChoosingAnchor, !retainsCenterPosition, waypoint == nil,
           let (anchor, separation) = nearbyLegs.min(by: { $0.1 < $1.1 }), separation <= 3 {
            let snapped = route.coordinate(at: anchor)
            // Ambiguous hits at different positions stay free plots. The explicit return
            // picker can then distinguish the route occurrences without shifting the draft.
            if nearbyLegs.allSatisfy({ hit in
                route.sameLocation(snapped, route.coordinate(at: hit.0))
            }) {
                plotPosition = snapped
            }
        }
        return .init(position: plotPosition, anchors: anchors, waypoint: waypoint, pointID: pointID,
                     legHits: placingAtCenter ? nil : legHits(at: tap, on: map, presentation: presentation),
                     isRouteTap: !retainsCenterPosition && !anchors.isEmpty)
    }

    override func draw(_ rect: CGRect) {
        guard let map, let context = UIGraphicsGetCurrentContext() else { return }
        if let pending {
            drawPending(pending, on: map, in: context)
            return
        }
        guard let presentation else { return }
        let draft = presentation.draft
        let route = presentation.route
        let segments = draft.segments(on: route)
        drawSegments(segments, proposedDashed: false, on: map, in: context)
        drawOriginalMinuteMarks(presentation, on: map, in: context)
        drawSelectedLeg(presentation, on: map, in: context)
        let reserved = [draft.departure, draft.rejoin].compactMap { $0 }
        let plottedStops = draft.points.filter { $0.name != nil }
        for stop in route.stops where !reserved.contains(stop.id) &&
            !plottedStops.contains(where: { $0.position == stop.position }) {
            let color = draft.bypasses(stop.id, on: route) ? Self.bypassedColor : Self.retainedColor
            marker(project(stop.position, on: map), label: stop.name, color: color, in: context)
        }
        for (index, point) in draft.points.enumerated() {
            let selected = draft.selectedPointID == point.id
            marker(project(point.position, on: map), label: point.name ?? "Point \(index + 1)",
                   color: Self.proposedColor, selected: selected, in: context)
        }
        if let departure = draft.departure {
            let label = draft.step == .staleDeparture ? "Previous departure" : "Departure"
            marker(project(route.coordinate(at: departure), on: map),
                   label: "\(label) · \(route.name(for: departure))", color: Self.proposedColor, in: context)
        }
        if let rejoin = draft.rejoin {
            marker(project(route.coordinate(at: rejoin), on: map), label: "Return · \(route.name(for: rejoin))", color: Self.proposedColor, in: context)
        }
        if let position = draft.overlapPosition {
            let point = project(position, on: map)
            let circle = CGRect(x: point.x - 14, y: point.y - 14, width: 28, height: 28)
            context.setLineDash(phase: 0, lengths: [])
            context.setStrokeColor(UIColor.white.cgColor)
            context.setLineWidth(6)
            context.strokeEllipse(in: circle)
            context.setStrokeColor(Self.retainedColor.cgColor)
            context.setLineWidth(2.5)
            context.strokeEllipse(in: circle)
        }
        if case .crossing(let options, _) = draft.step, let first = options.first {
            marker(project(route.coordinate(at: first), on: map), label: "Choose leg",
                   color: Self.proposedColor, selected: true, in: context)
        }
        if case .confirmRejoin(let anchor) = draft.step {
            marker(project(route.coordinate(at: anchor), on: map), label: route.name(for: anchor),
                   color: Self.proposedColor, selected: true, in: context)
        }
    }

    private func drawPending(_ pending: Pending, on map: MLNMapView, in context: CGContext) {
        let amendment = pending.amendment
        let route = pending.route
        let original = route.originalSegments(departure: amendment.departure, rejoin: amendment.rejoin)
        if pending.isActivated {
            drawSegments(original.filter { $0.role == .bypassed }, proposedDashed: false, on: map, in: context)
            for stop in route.stops where route.precedes(amendment.departure, stop.id) && route.precedes(stop.id, amendment.rejoin) {
                let point = project(stop.position, on: map)
                guard bounds.insetBy(dx: -20, dy: -20).contains(point) else { continue }
                marker(point, label: "\(stop.name) · bypassed", color: Self.bypassedColor, in: context)
            }
            if let activeReplacementLegID = pending.activeReplacementLegID, let rejoin = amendment.replacementLegs.last?.to,
               rejoin.id != amendment.replacementLegs.first(where: { $0.id == activeReplacementLegID })?.to.id {
                marker(project(rejoin.position, on: map), label: rejoin.name, color: Self.bypassedColor, in: context)
            }
            return
        }
        let proposal = amendment.replacementLegs.map {
            RouteAmendmentDraft.Segment(from: $0.from.position, to: $0.to.position, role: .proposed)
        }
        drawSegments(original + proposal, proposedDashed: true, on: map, in: context)

        let departure = pending.activePartwayDeparture.map {
            (marker: DepartureMarker(name: $0.name, traits: traitCollection), point: project($0.position, on: map))
        }
        let departureBadge = showsPartwayDepartureLabel ? departure.map { $0.marker.badgeRect(at: $0.point) } : nil
        var proposedMarkers = amendment.replacementLegs.dropLast().map { (project($0.to.position, on: map), $0.to.name) }
        if let rejoin = amendment.replacementLegs.last?.to {
            proposedMarkers.append((project(rejoin.position, on: map), "Rejoin · \(rejoin.name)"))
        }
        let labelViewport = bounds.inset(
            by: UIEdgeInsets(top: pending.departureHeaderInset + 4, left: 4, bottom: 4, right: 4)
        )
        var reservedBadges = proposedMarkers.map { markerLabel(at: $0.0, title: $0.1, radius: 5).frame }
        if let departureBadge {
            reservedBadges.append(departureBadge)
        }

        for stop in route.stops where route.precedes(amendment.departure, stop.id) && route.precedes(stop.id, amendment.rejoin) {
            let point = project(stop.position, on: map)
            guard bounds.insetBy(dx: -20, dy: -20).contains(point) else { continue }
            var label = markerLabel(at: point, title: "\(stop.name) · bypassed", radius: 5)
            if let departureBadge, label.frame.intersects(departureBadge) {
                label.frame = clearLabelFrame(near: label.frame, in: labelViewport, avoiding: reservedBadges)
            }
            drawMarker(at: point, label: label, color: Self.bypassedColor, selected: false, in: context)
            reservedBadges.append(label.frame)
        }
        for (point, title) in proposedMarkers {
            marker(point, label: title, color: Self.proposedColor, in: context)
        }
        if let departure {
            departure.marker.draw(at: departure.point, color: Self.retainedColor,
                                  showsLabel: showsPartwayDepartureLabel, in: context)
        }
    }

    private func drawSegments(
        _ segments: [RouteAmendmentDraft.Segment], proposedDashed: Bool,
        on map: MLNMapView, in context: CGContext
    ) {
        for role: RouteAmendmentDraft.Segment.Role in [.retained, .bypassed, .proposed] {
            for segment in segments where segment.role == role {
                let from = project(segment.from, on: map)
                let to = project(segment.to, on: map)
                let color: UIColor
                switch role {
                case .retained: color = Self.retainedColor
                case .bypassed: color = Self.bypassedColor
                case .proposed: color = Self.proposedColor
                }
                stroke(from, to, color: .white, width: 7, dashed: role == .bypassed || (proposedDashed && role == .proposed), in: context)
                stroke(from, to, color: color, width: 3.5, dashed: role == .bypassed || (proposedDashed && role == .proposed), in: context)
            }
        }
    }

    private func legHits(
        at point: CGPoint, on map: MLNMapView, presentation: Presentation
    ) -> [RouteAmendmentDraft.LegChoice] {
        func hits(_ from: WGS84Coordinate, _ to: WGS84Coordinate) -> Bool {
            let start = project(from, on: map)
            let end = project(to, on: map)
            let dx = end.x - start.x
            let dy = end.y - start.y
            let lengthSquared = dx * dx + dy * dy
            guard lengthSquared > 0 else { return false }
            let fraction = min(1, max(0, ((point.x - start.x) * dx + (point.y - start.y) * dy) / lengthSquared))
            return distance(point, CGPoint(x: start.x + dx * fraction, y: start.y + dy * fraction)) <= 18
        }
        let originals = presentation.route.legs.filter { hits($0.departure.position, $0.arrival.position) }
            .map { RouteAmendmentDraft.LegChoice.original($0.id) }
        guard !presentation.draft.isInspecting else { return originals }
        let proposed = presentation.draft.reviewLegs(on: presentation.route)
            .filter { hits($0.from, $0.to) }.map { RouteAmendmentDraft.LegChoice.proposed($0.id) }
        return originals + proposed
    }

    private func drawOriginalMinuteMarks(_ presentation: Presentation, on map: MLNMapView, in context: CGContext) {
        let route = presentation.route
        let style = AviationMapVisualStyle.default
        for (index, leg) in route.legs.enumerated() {
            guard let duration = route.originalLeg(leg.id)?.durationSeconds, duration >= 60 else { continue }
            let start = project(leg.departure.position, on: map)
            let end = project(leg.arrival.position, on: map)
            let dx = end.x - start.x
            let dy = end.y - start.y
            let length = hypot(dx, dy)
            guard length > 0 else { continue }
            let interval = length * 60 / CGFloat(duration)
            guard interval >= 4 else { continue }
            for minute in 1...(duration / 60) {
                let fraction = Double(minute * 60) / Double(duration)
                let anchor = route.anchor(at: index, fraction: fraction)
                let point = CGPoint(x: start.x + dx * fraction, y: start.y + dy * fraction)
                guard bounds.insetBy(dx: -16, dy: -16).contains(point) else { continue }
                let tickLength: CGFloat = minute.isMultiple(of: AviationMapSymbology.minuteLabelCadence) ? 10 : 7
                let tip = CGPoint(x: point.x + dy / length * tickLength, y: point.y - dx / length * tickLength)
                let bypassed = presentation.draft.bypasses(anchor, on: route)
                let color = bypassed ? Self.bypassedColor.withAlphaComponent(0.75) : Self.retainedColor
                stroke(point, tip, color: style.minuteTickCasingColor, width: 4, dashed: false, in: context)
                stroke(point, tip, color: color, width: 2, dashed: false, in: context)
            }
        }
    }

    private func drawSelectedLeg(_ presentation: Presentation, on map: MLNMapView, in context: CGContext) {
        switch presentation.draft.legPanel {
        case .editor:
            guard let id = presentation.draft.editor?.id,
                  let leg = presentation.draft.reviewLegs(on: presentation.route).first(where: { $0.id == id }) else { return }
            stroke(project(leg.from, on: map), project(leg.to, on: map),
                   color: Self.proposedColor, width: 5, dashed: false, in: context)
        case .original(let id, _):
            guard let leg = presentation.route.legs.first(where: { $0.id == id }) else { return }
            stroke(project(leg.departure.position, on: map), project(leg.arrival.position, on: map),
                   color: Self.retainedColor.withAlphaComponent(0.28), width: 13, dashed: false, in: context)
        default: break
        }
    }

    private func project(_ coordinate: WGS84Coordinate, on map: MLNMapView) -> CGPoint {
        map.convert(.init(latitude: coordinate.latitudeDegrees, longitude: coordinate.longitudeDegrees), toPointTo: map)
    }

    private func distance(_ first: CGPoint, _ second: CGPoint) -> CGFloat {
        hypot(first.x - second.x, first.y - second.y)
    }

    private func stroke(
        _ from: CGPoint, _ to: CGPoint, color: UIColor, width: CGFloat, dashed: Bool, in context: CGContext
    ) {
        context.setLineWidth(width)
        context.setStrokeColor(color.cgColor)
        context.setLineCap(.round)
        context.setLineDash(phase: 0, lengths: dashed ? [8, 9] : [])
        context.move(to: from)
        context.addLine(to: to)
        context.strokePath()
    }

    private struct MarkerLabel {
        let text: NSAttributedString
        var frame: CGRect
    }

    private func markerLabel(at point: CGPoint, title: String, radius: CGFloat) -> MarkerLabel {
        let text = NSAttributedString(string: title, attributes: [
            .font: UIFont.preferredFont(forTextStyle: .caption1),
            .foregroundColor: UIColor.label
        ])
        let size = text.size()
        let right = point.x + radius + 7
        let left = point.x - radius - 7 - size.width
        let maximumX = bounds.width - size.width - 9
        // Keep the label beside its marker when the right edge has less room.
        let preferredX = presentation != nil && right > maximumX ? left : right
        let x = max(4, min(preferredX, maximumX))
        let origin = CGPoint(x: x, y: point.y - size.height / 2)
        return MarkerLabel(text: text, frame: CGRect(origin: origin, size: size).insetBy(dx: -4, dy: -2))
    }

    private func clearLabelFrame(near frame: CGRect, in viewport: CGRect, avoiding obstacles: [CGRect]) -> CGRect {
        // Test the closest clear edges in both axes while keeping the plotted marker fixed.
        let gap: CGFloat = 0.5
        let xs = [frame.minX] + obstacles.flatMap { [$0.minX - frame.width - gap, $0.maxX + gap] }
        let ys = [frame.minY] + obstacles.flatMap { [$0.minY - frame.height - gap, $0.maxY + gap] }
        var closest = frame
        var closestDistance = CGFloat.infinity
        for x in xs {
            for y in ys {
                let distance = hypot(x - frame.minX, y - frame.minY)
                guard distance < closestDistance else { continue }
                let candidate = CGRect(origin: CGPoint(x: x, y: y), size: frame.size)
                guard viewport.contains(candidate),
                      !obstacles.contains(where: { $0.intersects(candidate) }) else { continue }
                closest = candidate
                closestDistance = distance
            }
        }
        return closest
    }

    private func marker(_ point: CGPoint, label: String, color: UIColor, selected: Bool = false, in context: CGContext) {
        guard bounds.insetBy(dx: -20, dy: -20).contains(point) else { return }
        let layout = markerLabel(at: point, title: label, radius: selected ? 9 : 5)
        drawMarker(at: point, label: layout, color: color, selected: selected, in: context)
    }

    private func drawMarker(at point: CGPoint, label: MarkerLabel, color: UIColor, selected: Bool, in context: CGContext) {
        let radius: CGFloat = selected ? 9 : 5
        let circle = CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)
        context.setFillColor(color.cgColor)
        context.fillEllipse(in: circle.insetBy(dx: -2, dy: -2))
        context.setFillColor(UIColor.white.cgColor)
        context.fillEllipse(in: circle)
        if selected {
            context.setFillColor(color.cgColor)
            context.fillEllipse(in: circle.insetBy(dx: 3, dy: 3))
        }

        UIColor.systemBackground.withAlphaComponent(0.92).setFill()
        UIBezierPath(roundedRect: label.frame, cornerRadius: 5).fill()
        label.text.draw(at: CGPoint(x: label.frame.minX + 4, y: label.frame.minY + 2))
    }
}
