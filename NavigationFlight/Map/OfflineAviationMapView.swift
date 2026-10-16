import CoreLocation
import MapLibre
import SwiftUI
import UIKit

enum AviationMapFocusMode: Equatable, Sendable {
    case leg
    case waypoint
    case overview
}

struct AviationMapFocusRequest: Equatable, Sendable {
    let id = UUID()
    let mode: AviationMapFocusMode
}

protocol AviationMapResourceProviding: Sendable {
    func styleURL() -> URL?
    func chartURL() -> URL?
}

struct BundledAviationMapResourceProvider: AviationMapResourceProviding {
    let bundle: Bundle

    init(bundle: Bundle = .main) {
        self.bundle = bundle
    }

    func styleURL() -> URL? {
        bundle.url(forResource: "blank-style", withExtension: "json")
    }

    func chartURL() -> URL? {
        bundle.url(forResource: "navigation-north", withExtension: "pmtiles")
    }
}

struct OfflineAviationMapView: UIViewRepresentable {
    let presentation: AviationMapPresentation
    let legState: FlightSession.LegState
    let focusRequest: AviationMapFocusRequest
    let resources: any AviationMapResourceProviding
    let visualStyle: AviationMapVisualStyle
    @Binding var etaCalloutOffset: AviationMapCalloutOffset
    @Binding var preservedCamera: AviationMapCameraState?
    @Binding var isCameraUserControlled: Bool

    init(
        presentation: AviationMapPresentation,
        legState: FlightSession.LegState,
        focusRequest: AviationMapFocusRequest,
        resources: any AviationMapResourceProviding = BundledAviationMapResourceProvider(),
        visualStyle: AviationMapVisualStyle = .default,
        etaCalloutOffset: Binding<AviationMapCalloutOffset>,
        preservedCamera: Binding<AviationMapCameraState?>,
        isCameraUserControlled: Binding<Bool>
    ) {
        self.presentation = presentation
        self.legState = legState
        self.focusRequest = focusRequest
        self.resources = resources
        self.visualStyle = visualStyle
        _etaCalloutOffset = etaCalloutOffset
        _preservedCamera = preservedCamera
        _isCameraUserControlled = isCameraUserControlled
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            presentation: presentation,
            legState: legState,
            focusRequest: focusRequest,
            chartURL: resources.chartURL(),
            visualStyle: visualStyle,
            etaCalloutOffset: $etaCalloutOffset,
            initialCamera: preservedCamera,
            preservedCamera: $preservedCamera,
            isCameraUserControlled: $isCameraUserControlled
        )
    }

    func makeUIView(context: Context) -> MLNMapView {
        let mapView = MLNMapView(frame: .zero, styleURL: resources.styleURL())
        mapView.delegate = context.coordinator
        mapView.automaticallyAdjustsContentInset = false
        mapView.showsUserLocation = false
        mapView.logoView.isHidden = true
        mapView.attributionButton.isHidden = true
        return mapView
    }

    func updateUIView(_ mapView: MLNMapView, context: Context) {
        context.coordinator.update(
            presentation: presentation,
            legState: legState,
            focusRequest: focusRequest,
            mapView: mapView
        )
    }

    final class Coordinator: NSObject, MLNMapViewDelegate {
        private enum Identifier {
            static let chartSource = "offline-aviation-chart-source"
            static let chartLayer = "offline-aviation-chart-layer"
            static let routeSource = "planned-route-source"
            static let routeLayer = "planned-route-layer"
            static let activeLayer = "active-leg-layer"
            static let previewSource = "next-leg-preview-source"
            static let previewLayer = "next-leg-preview-layer"
            static let waypointSource = "route-waypoint-source"
            static let waypointLayer = "route-waypoint-layer"
            static let minuteMarkSource = "active-leg-minute-mark-source"
            static let minuteMarkCasingLayer = "active-leg-minute-mark-casing-layer"
            static let minuteMarkLayer = "active-leg-minute-mark-layer"
        }

        private var presentation: AviationMapPresentation
        private var legState: FlightSession.LegState
        private var lastFocusRequest: AviationMapFocusRequest
        private let chartURL: URL?
        private let visualStyle: AviationMapVisualStyle
        private let etaCalloutOffset: Binding<AviationMapCalloutOffset>
        private let initialCamera: AviationMapCameraState?
        private let preservedCamera: Binding<AviationMapCameraState?>
        private let isCameraUserControlled: Binding<Bool>
        private var styleIsReady = false
        private var endpointAnnotations: [MLNPointAnnotation] = []
        private weak var etaCalloutView: DestinationCalloutAnnotationView?

        init(
            presentation: AviationMapPresentation,
            legState: FlightSession.LegState,
            focusRequest: AviationMapFocusRequest,
            chartURL: URL?,
            visualStyle: AviationMapVisualStyle,
            etaCalloutOffset: Binding<AviationMapCalloutOffset>,
            initialCamera: AviationMapCameraState?,
            preservedCamera: Binding<AviationMapCameraState?>,
            isCameraUserControlled: Binding<Bool>
        ) {
            self.presentation = presentation
            self.legState = legState
            self.lastFocusRequest = focusRequest
            self.chartURL = chartURL
            self.visualStyle = visualStyle
            self.etaCalloutOffset = etaCalloutOffset
            self.initialCamera = initialCamera
            self.preservedCamera = preservedCamera
            self.isCameraUserControlled = isCameraUserControlled
        }

        func mapView(_ mapView: MLNMapView, didFinishLoading style: MLNStyle) {
            addChart(to: style)
            addRoute(to: style)
            addWaypoints(to: style)
            addMinuteMarks(to: style)
            updateEndpointAnnotations(on: mapView)
            styleIsReady = true
            if isCameraUserControlled.wrappedValue, let initialCamera {
                restore(initialCamera, on: mapView)
            } else {
                focusLeg(on: mapView, animated: false)
            }
        }

        func mapView(_ mapView: MLNMapView, regionWillChangeAnimated animated: Bool) {
            let hasActiveGesture = mapView.gestureRecognizers?.contains {
                $0.state == .began || $0.state == .changed
            } ?? false
            if hasActiveGesture {
                isCameraUserControlled.wrappedValue = true
            }
        }

        func mapView(_ mapView: MLNMapView, regionDidChangeAnimated animated: Bool) {
            guard styleIsReady else { return }
            preservedCamera.wrappedValue = AviationMapCameraState(
                center: AviationMapCoordinate(
                    latitude: mapView.centerCoordinate.latitude,
                    longitude: mapView.centerCoordinate.longitude
                ),
                zoomLevel: mapView.zoomLevel,
                direction: mapView.direction
            )
            constrainEtaCallout(on: mapView)
        }

        func mapView(_ mapView: MLNMapView, viewFor annotation: MLNAnnotation) -> MLNAnnotationView? {
            if let annotation = annotation as? EndpointAnnotation {
                let identifier = "endpoint-\(annotation.identifier.uuidString)"
                return EndpointAnnotationView(
                    annotation: annotation,
                    reuseIdentifier: identifier,
                    visualStyle: visualStyle
                )
            }
            if let annotation = annotation as? DestinationCalloutAnnotation {
                let callout = DestinationCalloutAnnotationView(
                    annotation: annotation,
                    visualStyle: visualStyle,
                    offset: etaCalloutOffset.wrappedValue
                ) { [weak self, weak mapView] proposedOffset, size in
                    guard let self, let mapView else { return proposedOffset }
                    let constrained = self.constrainedEtaCalloutOffset(
                        proposedOffset,
                        calloutSize: size,
                        on: mapView
                    )
                    self.etaCalloutOffset.wrappedValue = constrained
                    return constrained
                }
                etaCalloutView = callout
                return callout
            }
            if let annotation = annotation as? MinuteLabelAnnotation {
                return MinuteLabelAnnotationView(annotation: annotation, visualStyle: visualStyle)
            }
            return nil
        }

        func update(
            presentation: AviationMapPresentation,
            legState: FlightSession.LegState,
            focusRequest: AviationMapFocusRequest,
            mapView: MLNMapView
        ) {
            let becameActive = self.legState == .ready && legState == .active
            let activeLegChanged = self.presentation.activeLegIndex != presentation.activeLegIndex
            let legStateChanged = self.legState != legState
            let presentationChanged = self.presentation != presentation
            self.presentation = presentation
            self.legState = legState

            guard styleIsReady else {
                lastFocusRequest = focusRequest
                return
            }

            if presentationChanged, let style = mapView.style {
                updateShapes(in: style)
            }
            if presentationChanged || legStateChanged {
                updateEndpointAnnotations(on: mapView)
            }

            if becameActive || (activeLegChanged && legState == .active) {
                focusLeg(
                    on: mapView,
                    animated: !UIAccessibility.isReduceMotionEnabled,
                    duration: activeLegChanged ? 1.0 : nil
                )
            } else if activeLegChanged && legState == .ready {
                focusLeg(on: mapView, animated: !UIAccessibility.isReduceMotionEnabled)
            } else if lastFocusRequest.id != focusRequest.id {
                switch focusRequest.mode {
                case .leg:
                    focusLeg(on: mapView, animated: true)
                case .waypoint:
                    focusWaypoint(on: mapView)
                case .overview:
                    focusOverview(on: mapView)
                }
            }
            lastFocusRequest = focusRequest
        }

        private func addChart(to style: MLNStyle) {
            guard let chartURL,
                  let pmtilesURL = URL(string: "pmtiles://\(chartURL.absoluteString)") else {
                return
            }
            let source = MLNRasterTileSource(
                identifier: Identifier.chartSource,
                configurationURL: pmtilesURL,
                tileSize: 256
            )
            style.addSource(source)
            style.addLayer(MLNRasterStyleLayer(identifier: Identifier.chartLayer, source: source))
        }

        private func addRoute(to style: MLNStyle) {
            let source = MLNShapeSource(
                identifier: Identifier.routeSource,
                shape: routeShape(),
                options: nil
            )
            style.addSource(source)

            let planned = MLNLineStyleLayer(identifier: Identifier.routeLayer, source: source)
            planned.lineColor = NSExpression(forConstantValue: UIColor.black.withAlphaComponent(0.45))
            planned.lineWidth = NSExpression(forConstantValue: 3)
            planned.lineJoin = NSExpression(forConstantValue: "round")
            planned.lineCap = NSExpression(forConstantValue: "round")
            style.addLayer(planned)

            let active = MLNLineStyleLayer(identifier: Identifier.activeLayer, source: source)
            active.predicate = NSPredicate(format: "legIndex == %d", presentation.activeLegIndex)
            active.lineColor = NSExpression(forConstantValue: visualStyle.activeLegColor)
            active.lineWidth = NSExpression(forConstantValue: visualStyle.activeLegWidth)
            active.lineJoin = NSExpression(forConstantValue: "round")
            active.lineCap = NSExpression(forConstantValue: "round")
            style.addLayer(active)

            let previewSource = MLNShapeSource(
                identifier: Identifier.previewSource,
                shape: previewShape(),
                options: nil
            )
            style.addSource(previewSource)
            let preview = MLNLineStyleLayer(identifier: Identifier.previewLayer, source: previewSource)
            preview.lineColor = NSExpression(forConstantValue: visualStyle.nextLegAccentColor)
            preview.lineWidth = NSExpression(forConstantValue: 4)
            preview.lineOpacity = NSExpression(forConstantValue: 0.9)
            preview.lineDashPattern = NSExpression(forConstantValue: [1.5, 1.5])
            preview.lineCap = NSExpression(forConstantValue: "round")
            style.addLayer(preview)
        }

        private func addWaypoints(to style: MLNStyle) {
            let source = MLNShapeSource(
                identifier: Identifier.waypointSource,
                shape: waypointShape(),
                options: nil
            )
            style.addSource(source)
            let points = MLNCircleStyleLayer(identifier: Identifier.waypointLayer, source: source)
            points.circleRadius = NSExpression(forConstantValue: 4)
            points.circleColor = NSExpression(forConstantValue: UIColor.white.withAlphaComponent(0.85))
            points.circleStrokeColor = NSExpression(forConstantValue: UIColor.black.withAlphaComponent(0.7))
            points.circleStrokeWidth = NSExpression(forConstantValue: 1.5)
            style.addLayer(points)
        }

        private func addMinuteMarks(to style: MLNStyle) {
            let source = MLNShapeSource(
                identifier: Identifier.minuteMarkSource,
                shape: minuteMarkShape(),
                options: nil
            )
            style.addSource(source)

            let casing = MLNLineStyleLayer(identifier: Identifier.minuteMarkCasingLayer, source: source)
            casing.lineColor = NSExpression(
                forConstantValue: visualStyle.minuteTickCasingColor.withAlphaComponent(
                    visualStyle.minuteTickCasingOpacity
                )
            )
            casing.lineWidth = NSExpression(forConstantValue: visualStyle.minuteTickCasingWidth)
            casing.lineCap = NSExpression(forConstantValue: "round")
            style.addLayer(casing)

            let marks = MLNLineStyleLayer(identifier: Identifier.minuteMarkLayer, source: source)
            marks.lineColor = NSExpression(forConstantValue: visualStyle.minuteTickColor)
            marks.lineWidth = NSExpression(forConstantValue: visualStyle.minuteTickWidth)
            marks.lineCap = NSExpression(forConstantValue: "round")
            style.addLayer(marks)
        }

        private func updateShapes(in style: MLNStyle) {
            (style.source(withIdentifier: Identifier.routeSource) as? MLNShapeSource)?.shape = routeShape()
            (style.source(withIdentifier: Identifier.previewSource) as? MLNShapeSource)?.shape = previewShape()
            (style.source(withIdentifier: Identifier.waypointSource) as? MLNShapeSource)?.shape = waypointShape()
            (style.source(withIdentifier: Identifier.minuteMarkSource) as? MLNShapeSource)?.shape = minuteMarkShape()
            (style.layer(withIdentifier: Identifier.activeLayer) as? MLNLineStyleLayer)?.predicate =
                NSPredicate(format: "legIndex == %d", presentation.activeLegIndex)
        }

        private func routeShape() -> MLNShapeCollectionFeature {
            MLNShapeCollectionFeature(shapes: presentation.legs.map { leg in
                lineFeature(from: leg.from, to: leg.to, attributes: ["legIndex": leg.index])
            })
        }

        private func previewShape() -> MLNShapeCollectionFeature {
            guard let leg = presentation.nextLegPreview else {
                return MLNShapeCollectionFeature(shapes: [])
            }
            let end = AviationMapGeometry.interpolate(from: leg.from, to: leg.to, fraction: 0.35)
            return MLNShapeCollectionFeature(
                shapes: [lineFeature(from: leg.from, to: end, attributes: [:])]
            )
        }

        private func waypointShape() -> MLNShapeCollectionFeature {
            MLNShapeCollectionFeature(shapes: presentation.waypoints.map { waypoint in
                let feature = MLNPointFeature()
                feature.coordinate = coordinate(waypoint.coordinate)
                return feature
            })
        }

        private func minuteMarkShape() -> MLNShapeCollectionFeature {
            guard let leg = presentation.activeLeg else {
                return MLNShapeCollectionFeature(shapes: [])
            }
            return MLNShapeCollectionFeature(shapes: presentation.minuteMarkers.map { marker in
                let end = minuteMarkEnd(from: marker.coordinate, on: leg, level: marker.level)
                return lineFeature(from: marker.coordinate, to: end, attributes: [:])
            })
        }

        private func minuteMarkEnd(
            from coordinate: AviationMapCoordinate,
            on leg: AviationMapLeg,
            level: AviationMapMinuteMarkLevel
        ) -> AviationMapCoordinate {
            let latitudeRadians = coordinate.latitude * .pi / 180
            let longitudeScale = max(cos(latitudeRadians), 0.2)
            let east = (leg.to.longitude - leg.from.longitude) * longitudeScale
            let north = leg.to.latitude - leg.from.latitude
            let magnitude = max(hypot(east, north), .leastNonzeroMagnitude)
            let length = magnitude * visualStyle.minuteTickLengthFraction(for: level)
            return AviationMapCoordinate(
                latitude: coordinate.latitude - (east / magnitude) * length,
                longitude: coordinate.longitude + (north / magnitude) * length / longitudeScale
            )
        }

        private func focusLeg(
            on mapView: MLNMapView,
            animated: Bool,
            duration: TimeInterval? = nil
        ) {
            guard let leg = presentation.activeLeg else { return }
            isCameraUserControlled.wrappedValue = false
            if legState == .ready {
                let outgoing = AviationMapGeometry.interpolate(from: leg.from, to: leg.to, fraction: 0.72)
                fit(
                    [leg.from, outgoing],
                    on: mapView,
                    padding: UIEdgeInsets(top: 130, left: 105, bottom: 115, right: 145),
                    animated: animated
                )
                mapView.setDirection(0, animated: animated)
            } else {
                var coordinates = [leg.from, leg.to]
                if let next = presentation.nextLegPreview {
                    coordinates.append(
                        AviationMapGeometry.interpolate(from: next.from, to: next.to, fraction: 0.18)
                    )
                }
                fitTrackUp(
                    coordinates,
                    on: mapView,
                    direction: AviationMapGeometry.bearing(from: leg.from, to: leg.to),
                    padding: UIEdgeInsets(top: 180, left: 75, bottom: 110, right: 120),
                    animated: animated,
                    duration: duration
                )
            }
        }

        private func focusWaypoint(on mapView: MLNMapView) {
            guard let leg = presentation.activeLeg else { return }
            isCameraUserControlled.wrappedValue = false
            if legState == .ready {
                let outgoing = AviationMapGeometry.interpolate(from: leg.from, to: leg.to, fraction: 0.38)
                fitTrackUp(
                    [leg.from, outgoing],
                    on: mapView,
                    direction: 0,
                    padding: UIEdgeInsets(top: 170, left: 105, bottom: 130, right: 145),
                    animated: true
                )
                return
            }
            let inbound = AviationMapGeometry.interpolate(from: leg.from, to: leg.to, fraction: 0.55)
            var coordinates = [inbound, leg.to]
            if let next = presentation.nextLegPreview {
                coordinates.append(
                    AviationMapGeometry.interpolate(from: next.from, to: next.to, fraction: 0.15)
                )
            }
            fitTrackUp(
                coordinates,
                on: mapView,
                direction: AviationMapGeometry.bearing(from: leg.from, to: leg.to),
                padding: UIEdgeInsets(top: 210, left: 95, bottom: 120, right: 135),
                animated: true
            )
        }

        private func focusOverview(on mapView: MLNMapView) {
            isCameraUserControlled.wrappedValue = false
            fit(
                presentation.waypoints.map { $0.coordinate },
                on: mapView,
                padding: UIEdgeInsets(top: 120, left: 110, bottom: 85, right: 220),
                animated: true
            )
            mapView.setDirection(0, animated: true)
        }

        private func fit(
            _ coordinates: [AviationMapCoordinate],
            on mapView: MLNMapView,
            padding: UIEdgeInsets,
            animated: Bool
        ) {
            guard let minimumLatitude = coordinates.map(\.latitude).min(),
                  let maximumLatitude = coordinates.map(\.latitude).max(),
                  let minimumLongitude = coordinates.map(\.longitude).min(),
                  let maximumLongitude = coordinates.map(\.longitude).max() else {
                return
            }
            let latitudeMargin = max((maximumLatitude - minimumLatitude) * 0.08, 0.002)
            let longitudeMargin = max((maximumLongitude - minimumLongitude) * 0.08, 0.002)
            let bounds = MLNCoordinateBounds(
                sw: CLLocationCoordinate2D(
                    latitude: minimumLatitude - latitudeMargin,
                    longitude: minimumLongitude - longitudeMargin
                ),
                ne: CLLocationCoordinate2D(
                    latitude: maximumLatitude + latitudeMargin,
                    longitude: maximumLongitude + longitudeMargin
                )
            )
            mapView.setVisibleCoordinateBounds(
                bounds,
                edgePadding: padding,
                animated: animated,
                completionHandler: nil
            )
        }

        private func fitTrackUp(
            _ coordinates: [AviationMapCoordinate],
            on mapView: MLNMapView,
            direction: CLLocationDirection,
            padding: UIEdgeInsets,
            animated: Bool,
            duration: TimeInterval? = nil
        ) {
            var mapCoordinates = coordinates.map(coordinate)
            let shape = MLNPolylineFeature(
                coordinates: &mapCoordinates,
                count: UInt(mapCoordinates.count)
            )
            let camera = mapView.cameraThatFitsShape(
                shape,
                direction: direction,
                edgePadding: padding
            )
            if animated, let duration {
                mapView.setCamera(
                    camera,
                    withDuration: duration,
                    animationTimingFunction: CAMediaTimingFunction(name: .easeInEaseOut)
                )
            } else {
                mapView.setCamera(camera, animated: animated)
            }
        }

        private func updateEndpointAnnotations(on mapView: MLNMapView) {
            if !endpointAnnotations.isEmpty {
                mapView.removeAnnotations(endpointAnnotations)
            }
            endpointAnnotations = presentation.waypoints.compactMap { waypoint in
                guard waypoint.role != .route else { return nil }
                let reference = presentation.endpointReferences.first { $0.waypointID == waypoint.id }
                return EndpointAnnotation(
                    waypoint: waypoint,
                    reference: reference,
                    isActive: legState == .active
                )
            }
            if let destination = presentation.waypoints.first(where: { $0.role == .to }) {
                let reference = presentation.endpointReferences.first { $0.waypointID == destination.id }
                endpointAnnotations.append(
                    DestinationCalloutAnnotation(
                        waypoint: destination,
                        reference: reference,
                        plannedDurationText: presentation.plannedDurationText
                    )
                )
            }
            endpointAnnotations.append(contentsOf: presentation.minuteMarkers.compactMap { marker in
                marker.showsLabel ? MinuteLabelAnnotation(marker: marker) : nil
            })
            mapView.addAnnotations(endpointAnnotations)
        }

        private func constrainEtaCallout(on mapView: MLNMapView) {
            guard let etaCalloutView else { return }
            let constrained = constrainedEtaCalloutOffset(
                etaCalloutOffset.wrappedValue,
                calloutSize: etaCalloutView.bounds.size,
                on: mapView
            )
            etaCalloutOffset.wrappedValue = constrained
            etaCalloutView.apply(offset: constrained)
        }

        private func constrainedEtaCalloutOffset(
            _ proposed: AviationMapCalloutOffset,
            calloutSize: CGSize,
            on mapView: MLNMapView
        ) -> AviationMapCalloutOffset {
            guard let destination = presentation.activeFocusTarget else { return proposed }
            let anchor = mapView.convert(coordinate(destination), toPointTo: mapView)
            let halfWidth = calloutSize.width / 2
            let halfHeight = calloutSize.height / 2
            let usableBounds = mapView.bounds.inset(
                by: UIEdgeInsets(top: 125, left: 12, bottom: 12, right: 82)
            )
            let minimumX = usableBounds.minX + halfWidth - anchor.x
            let maximumX = usableBounds.maxX - halfWidth - anchor.x
            let minimumY = usableBounds.minY + halfHeight - anchor.y
            let maximumY = usableBounds.maxY - halfHeight - anchor.y
            return AviationMapCalloutOffset(
                x: min(max(proposed.x, minimumX), maximumX),
                y: min(max(proposed.y, minimumY), maximumY)
            )
        }

        private func restore(_ camera: AviationMapCameraState, on mapView: MLNMapView) {
            mapView.setCenter(
                coordinate(camera.center),
                zoomLevel: camera.zoomLevel,
                direction: camera.direction,
                animated: false
            )
        }

        private func lineFeature(
            from: AviationMapCoordinate,
            to: AviationMapCoordinate,
            attributes: [String: Any]
        ) -> MLNPolylineFeature {
            var coordinates = [coordinate(from), coordinate(to)]
            let feature = MLNPolylineFeature(coordinates: &coordinates, count: UInt(coordinates.count))
            feature.attributes = attributes
            return feature
        }

        private func coordinate(_ value: AviationMapCoordinate) -> CLLocationCoordinate2D {
            CLLocationCoordinate2D(latitude: value.latitude, longitude: value.longitude)
        }
    }
}

private final class EndpointAnnotation: MLNPointAnnotation {
    let identifier: UUID
    let role: AviationMapWaypoint.Role
    let waypointName: String
    let referenceText: String?
    let isActive: Bool

    init(
        waypoint: AviationMapWaypoint,
        reference: AviationMapVORDMEReference?,
        isActive: Bool
    ) {
        identifier = waypoint.id
        role = waypoint.role
        waypointName = waypoint.name
        self.isActive = isActive
        if let reference {
            let radial = Int(reference.magneticRadialFromDegrees.rounded())
            referenceText = "\(reference.stationIdentifier) · \(reference.frequencyMHz.formatted(.number.precision(.fractionLength(2...3)))) · \(radial)° · \(reference.slantRangeNauticalMiles.formatted(.number.precision(.fractionLength(1)))) NM"
        } else {
            referenceText = nil
        }
        super.init()
        coordinate = CLLocationCoordinate2D(
            latitude: waypoint.coordinate.latitude,
            longitude: waypoint.coordinate.longitude
        )
    }

    required init?(coder: NSCoder) {
        return nil
    }
}

private final class EndpointAnnotationView: MLNAnnotationView {
    init(
        annotation: EndpointAnnotation,
        reuseIdentifier: String,
        visualStyle: AviationMapVisualStyle
    ) {
        super.init(reuseIdentifier: reuseIdentifier)
        if annotation.role == .to {
            configureDestination(annotation, visualStyle: visualStyle)
        } else {
            configureDeparture(annotation)
        }
        isEnabled = false
    }

    private func configureDeparture(_ annotation: EndpointAnnotation) {
        let label = UILabel()
        label.numberOfLines = annotation.referenceText == nil ? 1 : 2
        label.font = .preferredFont(forTextStyle: .caption2)
        label.textColor = .label
        label.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.84)
        label.layer.cornerRadius = 4
        label.layer.masksToBounds = true
        label.text = [annotation.waypointName, annotation.referenceText].compactMap { $0 }.joined(separator: "\n")
        let measured = label.sizeThatFits(CGSize(width: 200, height: 52))
        let labelSize = CGSize(width: measured.width + 10, height: measured.height + 5)
        let size = CGSize(width: labelSize.width + 32, height: max(34, labelSize.height))
        frame = CGRect(origin: .zero, size: size)

        let symbol = WaypointSymbolView(destination: false)
        symbol.frame = CGRect(x: 4, y: bounds.midY - 9, width: 18, height: 18)
        addSubview(symbol)
        label.frame = CGRect(x: 28, y: bounds.midY - labelSize.height / 2, width: labelSize.width, height: labelSize.height)
        addSubview(label)
        centerOffset = CGVector(dx: bounds.midX - 13, dy: 0)
    }

    private func configureDestination(
        _ annotation: EndpointAnnotation,
        visualStyle: AviationMapVisualStyle
    ) {
        let diameter = (visualStyle.destinationWaypointRadius + 2) * 2
        frame = CGRect(origin: .zero, size: CGSize(width: diameter, height: diameter))
        let symbol = WaypointSymbolView(destination: true, visualStyle: visualStyle)
        symbol.frame = bounds
        addSubview(symbol)
        alpha = annotation.isActive ? 1 : 0.78
    }

    required init?(coder: NSCoder) {
        return nil
    }
}

private final class WaypointSymbolView: UIView {
    private let destination: Bool
    private let visualStyle: AviationMapVisualStyle

    init(destination: Bool, visualStyle: AviationMapVisualStyle = .default) {
        self.destination = destination
        self.visualStyle = visualStyle
        super.init(frame: .zero)
        backgroundColor = .clear
        isOpaque = false
    }

    override func draw(_ rect: CGRect) {
        let context = UIGraphicsGetCurrentContext()
        let inset: CGFloat = destination ? 2 : 3
        let circle = bounds.insetBy(dx: inset, dy: inset)
        let fillOpacity = destination ? visualStyle.destinationWaypointFillOpacity : 0.88
        let fillColor = destination ? visualStyle.destinationWaypointFillColor : UIColor.systemBackground
        fillColor.withAlphaComponent(fillOpacity).setFill()
        context?.fillEllipse(in: circle)
        let strokeColor = destination ? visualStyle.destinationWaypointStrokeColor : UIColor.label
        let strokeOpacity = destination ? visualStyle.destinationWaypointStrokeOpacity : 1
        strokeColor.withAlphaComponent(strokeOpacity).setStroke()
        context?.setLineWidth(destination ? visualStyle.destinationWaypointStrokeWidth : 2)
        context?.strokeEllipse(in: circle)

        guard !destination else { return }
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let radius: CGFloat = 3.5
        let triangle = UIBezierPath()
        triangle.move(to: CGPoint(x: center.x, y: center.y - radius))
        triangle.addLine(to: CGPoint(x: center.x + radius, y: center.y + radius * 0.8))
        triangle.addLine(to: CGPoint(x: center.x - radius, y: center.y + radius * 0.8))
        triangle.close()
        UIColor.systemBlue.setFill()
        triangle.fill()
    }

    required init?(coder: NSCoder) {
        return nil
    }
}

private final class DestinationCalloutAnnotation: MLNPointAnnotation {
    let waypointName: String
    let plannedDurationText: String
    let referenceText: String?

    init(
        waypoint: AviationMapWaypoint,
        reference: AviationMapVORDMEReference?,
        plannedDurationText: String
    ) {
        waypointName = waypoint.name
        self.plannedDurationText = plannedDurationText
        if let reference {
            let radial = Int(reference.magneticRadialFromDegrees.rounded())
            referenceText = "\(reference.stationIdentifier) · \(reference.frequencyMHz.formatted(.number.precision(.fractionLength(2...3)))) · \(radial)° · \(reference.slantRangeNauticalMiles.formatted(.number.precision(.fractionLength(1)))) NM"
        } else {
            referenceText = nil
        }
        super.init()
        coordinate = CLLocationCoordinate2D(
            latitude: waypoint.coordinate.latitude,
            longitude: waypoint.coordinate.longitude
        )
    }

    required init?(coder: NSCoder) {
        return nil
    }
}

private final class DestinationCalloutAnnotationView: MLNAnnotationView, UIGestureRecognizerDelegate {
    typealias OffsetHandler = (AviationMapCalloutOffset, CGSize) -> AviationMapCalloutOffset

    private var offset: AviationMapCalloutOffset
    private let offsetHandler: OffsetHandler
    private let leader = CAShapeLayer()

    init(
        annotation: DestinationCalloutAnnotation,
        visualStyle: AviationMapVisualStyle,
        offset: AviationMapCalloutOffset,
        offsetHandler: @escaping OffsetHandler
    ) {
        self.offset = offset
        self.offsetHandler = offsetHandler
        super.init(reuseIdentifier: "destination-eta-callout")

        let size = CGSize(width: 146, height: annotation.referenceText == nil ? 55 : 70)
        frame = CGRect(origin: .zero, size: size)
        clipsToBounds = false
        layer.masksToBounds = false

        leader.strokeColor = visualStyle.etaCalloutBorderColor
            .withAlphaComponent(visualStyle.etaCalloutBorderOpacity).cgColor
        leader.lineWidth = visualStyle.etaCalloutBorderWidth
        leader.fillColor = UIColor.clear.cgColor
        layer.insertSublayer(leader, at: 0)

        let content = DestinationCalloutView(annotation: annotation, visualStyle: visualStyle)
        content.frame = bounds
        addSubview(content)

        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        pan.delegate = self
        addGestureRecognizer(pan)
        isEnabled = true
        apply(offset: offset)
    }

    func apply(offset: AviationMapCalloutOffset) {
        let previous = self.offset
        self.offset = offset
        centerOffset = CGVector(dx: offset.x, dy: offset.y)
        if superview != nil {
            center = CGPoint(
                x: center.x + offset.x - previous.x,
                y: center.y + offset.y - previous.y
            )
        }
        updateLeader()
    }

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard let host = superview else { return }
        let translation = gesture.translation(in: host)
        let proposed = offset.translated(x: translation.x, y: translation.y)
        apply(offset: offsetHandler(proposed, bounds.size))
        gesture.setTranslation(.zero, in: host)
    }

    private func updateLeader() {
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let anchor = CGPoint(x: center.x - offset.x, y: center.y - offset.y)
        let delta = CGPoint(x: anchor.x - center.x, y: anchor.y - center.y)
        let horizontalScale = delta.x == 0 ? .greatestFiniteMagnitude : bounds.width / 2 / abs(delta.x)
        let verticalScale = delta.y == 0 ? .greatestFiniteMagnitude : bounds.height / 2 / abs(delta.y)
        let scale = min(horizontalScale, verticalScale)
        let edge = CGPoint(x: center.x + delta.x * scale, y: center.y + delta.y * scale)
        let path = UIBezierPath()
        path.move(to: edge)
        path.addLine(to: anchor)
        leader.path = path.cgPath
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        false
    }

    required init?(coder: NSCoder) {
        return nil
    }
}

private final class DestinationCalloutView: UIView {
    init(annotation: DestinationCalloutAnnotation, visualStyle: AviationMapVisualStyle) {
        super.init(frame: .zero)
        backgroundColor = visualStyle.etaCalloutBackgroundColor.withAlphaComponent(
            visualStyle.etaCalloutBackgroundOpacity
        )
        layer.borderColor = visualStyle.etaCalloutBorderColor.withAlphaComponent(
            visualStyle.etaCalloutBorderOpacity
        ).cgColor
        layer.borderWidth = visualStyle.etaCalloutBorderWidth
        layer.cornerRadius = 3

        let name = UILabel()
        name.text = annotation.waypointName
        name.textAlignment = .center
        name.font = .systemFont(
            ofSize: visualStyle.etaCalloutNameFontSize,
            weight: visualStyle.etaCalloutNameFontWeight
        )
        name.textColor = UIColor.secondaryLabel.withAlphaComponent(visualStyle.etaCalloutTextOpacity)

        let duration = UILabel()
        duration.text = annotation.plannedDurationText
        duration.textAlignment = .center
        duration.font = .monospacedDigitSystemFont(
            ofSize: visualStyle.etaCalloutDurationFontSize,
            weight: visualStyle.etaCalloutDurationFontWeight
        )
        duration.textColor = UIColor.label.withAlphaComponent(visualStyle.etaCalloutTextOpacity)

        let reference = UILabel()
        reference.text = annotation.referenceText
        reference.textAlignment = .center
        reference.font = .systemFont(ofSize: 9, weight: .medium)
        reference.textColor = .secondaryLabel
        reference.adjustsFontSizeToFitWidth = true
        reference.minimumScaleFactor = 0.75

        [name, duration, reference].forEach(addSubview)
        name.translatesAutoresizingMaskIntoConstraints = false
        duration.translatesAutoresizingMaskIntoConstraints = false
        reference.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            name.topAnchor.constraint(equalTo: topAnchor, constant: 5),
            name.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
            name.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
            duration.topAnchor.constraint(equalTo: name.bottomAnchor, constant: -1),
            duration.centerXAnchor.constraint(equalTo: centerXAnchor),
            reference.topAnchor.constraint(equalTo: duration.bottomAnchor, constant: 1),
            reference.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 5),
            reference.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -5)
        ])
        reference.isHidden = annotation.referenceText == nil
    }

    required init?(coder: NSCoder) {
        return nil
    }
}

private final class MinuteLabelAnnotation: MLNPointAnnotation {
    let minute: Int
    let isNearDestination: Bool

    init(marker: AviationMapMinuteMarker) {
        minute = marker.minute
        isNearDestination = marker.fraction >= 0.9
        super.init()
        coordinate = CLLocationCoordinate2D(
            latitude: marker.coordinate.latitude,
            longitude: marker.coordinate.longitude
        )
    }

    required init?(coder: NSCoder) {
        return nil
    }
}

private final class MinuteLabelAnnotationView: MLNAnnotationView {
    init(annotation: MinuteLabelAnnotation, visualStyle: AviationMapVisualStyle) {
        super.init(reuseIdentifier: "minute-\(annotation.minute)")
        let label = UILabel()
        label.text = String(annotation.minute)
        label.textAlignment = .center
        label.font = .monospacedDigitSystemFont(
            ofSize: visualStyle.minuteLabelFontSize,
            weight: visualStyle.minuteLabelFontWeight
        )
        label.textColor = .label
        label.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.82)
        label.layer.cornerRadius = 9
        label.layer.masksToBounds = true
        frame = CGRect(x: 0, y: 0, width: 22, height: 20)
        label.frame = bounds
        addSubview(label)
        centerOffset = annotation.isNearDestination
            ? CGVector(dx: 36, dy: 10)
            : CGVector(dx: 23, dy: 0)
        isEnabled = false
    }

    required init?(coder: NSCoder) {
        return nil
    }
}
