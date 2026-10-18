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
    @Binding var identificationPointCalloutOffsets: [IdentificationPointKey: AviationMapCalloutOffset]
    let identificationContext: AviationMapIdentificationContext?
    let timingTargetContext: AviationMapTimingTargetContext?
    @Binding var preservedCamera: AviationMapCameraState?
    @Binding var isCameraUserControlled: Bool
    let onSelectIdentificationPoint: (IdentificationPointKey) -> Void
    let onSelectTimingTarget: (NavigationTimingTargetKey) -> Void
    let onReachIdentificationPoint: () -> Void
    let onAdjustPilotETA: (NavigationTimingTargetKey, Int) -> Void
    let onCommitPilotETA: (NavigationTimingTargetKey) -> Void
    let onEditPilotETA: (NavigationTimingTargetKey) -> Void
    let onShowPilotETACheck: (NavigationTimingTargetKey) -> Void
    let onHidePilotETACheck: (NavigationTimingTargetKey) -> Void

    init(
        presentation: AviationMapPresentation,
        legState: FlightSession.LegState,
        focusRequest: AviationMapFocusRequest,
        resources: any AviationMapResourceProviding = BundledAviationMapResourceProvider(),
        visualStyle: AviationMapVisualStyle = .default,
        etaCalloutOffset: Binding<AviationMapCalloutOffset>,
        identificationPointCalloutOffsets: Binding<[IdentificationPointKey: AviationMapCalloutOffset]>,
        identificationContext: AviationMapIdentificationContext?,
        timingTargetContext: AviationMapTimingTargetContext?,
        preservedCamera: Binding<AviationMapCameraState?>,
        isCameraUserControlled: Binding<Bool>,
        onSelectIdentificationPoint: @escaping (IdentificationPointKey) -> Void,
        onSelectTimingTarget: @escaping (NavigationTimingTargetKey) -> Void,
        onReachIdentificationPoint: @escaping () -> Void,
        onAdjustPilotETA: @escaping (NavigationTimingTargetKey, Int) -> Void,
        onCommitPilotETA: @escaping (NavigationTimingTargetKey) -> Void,
        onEditPilotETA: @escaping (NavigationTimingTargetKey) -> Void,
        onShowPilotETACheck: @escaping (NavigationTimingTargetKey) -> Void,
        onHidePilotETACheck: @escaping (NavigationTimingTargetKey) -> Void
    ) {
        self.presentation = presentation
        self.legState = legState
        self.focusRequest = focusRequest
        self.resources = resources
        self.visualStyle = visualStyle
        _etaCalloutOffset = etaCalloutOffset
        _identificationPointCalloutOffsets = identificationPointCalloutOffsets
        self.identificationContext = identificationContext
        self.timingTargetContext = timingTargetContext
        _preservedCamera = preservedCamera
        _isCameraUserControlled = isCameraUserControlled
        self.onSelectIdentificationPoint = onSelectIdentificationPoint
        self.onSelectTimingTarget = onSelectTimingTarget
        self.onReachIdentificationPoint = onReachIdentificationPoint
        self.onAdjustPilotETA = onAdjustPilotETA
        self.onCommitPilotETA = onCommitPilotETA
        self.onEditPilotETA = onEditPilotETA
        self.onShowPilotETACheck = onShowPilotETACheck
        self.onHidePilotETACheck = onHidePilotETACheck
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            presentation: presentation,
            legState: legState,
            focusRequest: focusRequest,
            chartURL: resources.chartURL(),
            visualStyle: visualStyle,
            etaCalloutOffset: $etaCalloutOffset,
            identificationPointCalloutOffsets: $identificationPointCalloutOffsets,
            identificationContext: identificationContext,
            timingTargetContext: timingTargetContext,
            initialCamera: preservedCamera,
            preservedCamera: $preservedCamera,
            isCameraUserControlled: $isCameraUserControlled,
            onSelectIdentificationPoint: onSelectIdentificationPoint,
            onSelectTimingTarget: onSelectTimingTarget,
            onReachIdentificationPoint: onReachIdentificationPoint,
            onAdjustPilotETA: onAdjustPilotETA,
            onCommitPilotETA: onCommitPilotETA,
            onEditPilotETA: onEditPilotETA,
            onShowPilotETACheck: onShowPilotETACheck,
            onHidePilotETACheck: onHidePilotETACheck
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
            identificationContext: identificationContext,
            timingTargetContext: timingTargetContext,
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
        private var identificationContext: AviationMapIdentificationContext?
        private var timingTargetContext: AviationMapTimingTargetContext?
        private var lastFocusRequest: AviationMapFocusRequest
        private let chartURL: URL?
        private let visualStyle: AviationMapVisualStyle
        private let etaCalloutOffset: Binding<AviationMapCalloutOffset>
        private let identificationPointCalloutOffsets: Binding<[IdentificationPointKey: AviationMapCalloutOffset]>
        private var cachedIdentificationPointCalloutOffsets: [IdentificationPointKey: AviationMapCalloutOffset]
        private let initialCamera: AviationMapCameraState?
        private let preservedCamera: Binding<AviationMapCameraState?>
        private let isCameraUserControlled: Binding<Bool>
        private var styleIsReady = false
        private var endpointAnnotations: [MLNPointAnnotation] = []
        private weak var etaCalloutView: DestinationCalloutAnnotationView?
        private let onSelectIdentificationPoint: (IdentificationPointKey) -> Void
        private let onSelectTimingTarget: (NavigationTimingTargetKey) -> Void
        private let onReachIdentificationPoint: () -> Void
        private let onAdjustPilotETA: (NavigationTimingTargetKey, Int) -> Void
        private let onCommitPilotETA: (NavigationTimingTargetKey) -> Void
        private let onEditPilotETA: (NavigationTimingTargetKey) -> Void
        private let onShowPilotETACheck: (NavigationTimingTargetKey) -> Void
        private let onHidePilotETACheck: (NavigationTimingTargetKey) -> Void

        init(
            presentation: AviationMapPresentation,
            legState: FlightSession.LegState,
            focusRequest: AviationMapFocusRequest,
            chartURL: URL?,
            visualStyle: AviationMapVisualStyle,
            etaCalloutOffset: Binding<AviationMapCalloutOffset>,
            identificationPointCalloutOffsets: Binding<[IdentificationPointKey: AviationMapCalloutOffset]>,
            identificationContext: AviationMapIdentificationContext?,
            timingTargetContext: AviationMapTimingTargetContext?,
            initialCamera: AviationMapCameraState?,
            preservedCamera: Binding<AviationMapCameraState?>,
            isCameraUserControlled: Binding<Bool>,
            onSelectIdentificationPoint: @escaping (IdentificationPointKey) -> Void,
            onSelectTimingTarget: @escaping (NavigationTimingTargetKey) -> Void,
            onReachIdentificationPoint: @escaping () -> Void,
            onAdjustPilotETA: @escaping (NavigationTimingTargetKey, Int) -> Void,
            onCommitPilotETA: @escaping (NavigationTimingTargetKey) -> Void,
            onEditPilotETA: @escaping (NavigationTimingTargetKey) -> Void,
            onShowPilotETACheck: @escaping (NavigationTimingTargetKey) -> Void,
            onHidePilotETACheck: @escaping (NavigationTimingTargetKey) -> Void
        ) {
            self.presentation = presentation
            self.legState = legState
            self.identificationContext = identificationContext
            self.timingTargetContext = timingTargetContext
            self.lastFocusRequest = focusRequest
            self.chartURL = chartURL
            self.visualStyle = visualStyle
            self.etaCalloutOffset = etaCalloutOffset
            self.identificationPointCalloutOffsets = identificationPointCalloutOffsets
            cachedIdentificationPointCalloutOffsets = identificationPointCalloutOffsets.wrappedValue
            self.initialCamera = initialCamera
            self.preservedCamera = preservedCamera
            self.isCameraUserControlled = isCameraUserControlled
            self.onSelectIdentificationPoint = onSelectIdentificationPoint
            self.onSelectTimingTarget = onSelectTimingTarget
            self.onReachIdentificationPoint = onReachIdentificationPoint
            self.onAdjustPilotETA = onAdjustPilotETA
            self.onCommitPilotETA = onCommitPilotETA
            self.onEditPilotETA = onEditPilotETA
            self.onShowPilotETACheck = onShowPilotETACheck
            self.onHidePilotETACheck = onHidePilotETACheck
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
                    offset: etaCalloutOffset.wrappedValue,
                    context: timingTargetContext?.target.id == presentation.destinationTarget.id
                        ? timingTargetContext : nil,
                    onSelect: onSelectTimingTarget,
                    onAdjust: onAdjustPilotETA,
                    onCommit: onCommitPilotETA,
                    onEdit: onEditPilotETA,
                    onShowCheck: onShowPilotETACheck,
                    onHideCheck: onHidePilotETACheck
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
            if let annotation = annotation as? IdentificationPointSymbolAnnotation {
                return IdentificationPointSymbolAnnotationView(
                    annotation: annotation,
                    visualStyle: visualStyle,
                    onSelect: onSelectIdentificationPoint
                )
            }
            if let annotation = annotation as? IdentificationPointLabelAnnotation {
                let savedOffset = cachedIdentificationPointCalloutOffsets[annotation.point.id]
                    ?? identificationPointCalloutOffsets.wrappedValue[annotation.point.id]
                    ?? visualStyle.defaultIdentificationPointCalloutOffset
                return IdentificationPointLabelAnnotationView(
                    annotation: annotation,
                    visualStyle: visualStyle,
                    offset: savedOffset,
                    context: identificationContext?.pointID == annotation.point.id ? identificationContext : nil,
                    targetContext: timingTargetContext?.target.id.targetID == annotation.point.id.identificationPointID
                        && timingTargetContext?.target.id.legID == annotation.point.id.legID
                        ? timingTargetContext : nil,
                    onSelect: onSelectIdentificationPoint,
                    onReach: onReachIdentificationPoint,
                    onAdjust: onAdjustPilotETA,
                    onCommit: onCommitPilotETA,
                    onEdit: onEditPilotETA,
                    onRevise: onSelectTimingTarget,
                    onShowCheck: onShowPilotETACheck,
                    onHideCheck: onHidePilotETACheck
                ) { [weak self, weak mapView] proposed, size in
                    guard let self, let mapView else { return proposed }
                    let constrained = self.constrainedIdentificationPointOffset(
                        proposed,
                        calloutSize: size,
                        point: annotation.point,
                        on: mapView
                    )
                    self.cachedIdentificationPointCalloutOffsets[annotation.point.id] = constrained
                    self.identificationPointCalloutOffsets.wrappedValue[annotation.point.id] = constrained
                    return constrained
                }
            }
            return nil
        }

        func update(
            presentation: AviationMapPresentation,
            legState: FlightSession.LegState,
            identificationContext: AviationMapIdentificationContext?,
            timingTargetContext: AviationMapTimingTargetContext?,
            focusRequest: AviationMapFocusRequest,
            mapView: MLNMapView
        ) {
            let becameActive = self.legState == .ready && legState == .active
            let activeLegChanged = self.presentation.activeLegIndex != presentation.activeLegIndex
            let legStateChanged = self.legState != legState
            let presentationChanged = self.presentation != presentation
            let identificationContextChanged = self.identificationContext != identificationContext
            let timingTargetContextChanged = self.timingTargetContext != timingTargetContext
            self.presentation = presentation
            self.legState = legState
            self.identificationContext = identificationContext
            self.timingTargetContext = timingTargetContext
            if activeLegChanged {
                cachedIdentificationPointCalloutOffsets = identificationPointCalloutOffsets.wrappedValue
            }

            guard styleIsReady else {
                lastFocusRequest = focusRequest
                return
            }

            if presentationChanged, let style = mapView.style {
                updateShapes(in: style)
            }
            if presentationChanged || legStateChanged || identificationContextChanged || timingTargetContextChanged {
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
            var destinationCallout: DestinationCalloutAnnotation?
            if let destination = presentation.waypoints.first(where: { $0.role == .to }) {
                let reference = presentation.endpointReferences.first { $0.waypointID == destination.id }
                destinationCallout = DestinationCalloutAnnotation(
                    waypoint: destination,
                    reference: reference,
                    targetID: presentation.destinationTarget.id,
                    plannedElapsedSeconds: presentation.destinationTarget.plannedElapsedSeconds,
                    plannedDurationText: presentation.plannedDurationText,
                    committedETASeconds: presentation.destinationTarget.committedETASeconds
                )
            }
            endpointAnnotations.append(contentsOf: presentation.minuteMarkers.compactMap { marker in
                marker.showsLabel ? MinuteLabelAnnotation(marker: marker) : nil
            })
            for point in presentation.identificationPoints {
                endpointAnnotations.append(IdentificationPointSymbolAnnotation(point: point))
                endpointAnnotations.append(IdentificationPointLabelAnnotation(point: point))
            }
            if let destinationCallout {
                endpointAnnotations.append(destinationCallout)
            }
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

        private func constrainedIdentificationPointOffset(
            _ proposed: AviationMapCalloutOffset,
            calloutSize: CGSize,
            point: AviationMapIdentificationPoint,
            on mapView: MLNMapView
        ) -> AviationMapCalloutOffset {
            let anchor = mapView.convert(coordinate(point.coordinate), toPointTo: mapView)
            let usableBounds = mapView.bounds.inset(
                by: UIEdgeInsets(top: 126, left: 12, bottom: 12, right: 82)
            )
            let halfWidth = calloutSize.width / 2
            let halfHeight = calloutSize.height / 2
            var constrained = AviationMapCalloutOffset(
                x: min(max(proposed.x, usableBounds.minX + halfWidth - anchor.x), usableBounds.maxX - halfWidth - anchor.x),
                y: min(max(proposed.y, usableBounds.minY + halfHeight - anchor.y), usableBounds.maxY - halfHeight - anchor.y)
            )
            guard identificationContext?.pointID == point.id,
                  let destinationFrame = etaCalloutView?.frame.insetBy(dx: -10, dy: -10) else {
                return constrained
            }
            var candidate = CGRect(
                x: anchor.x + constrained.x - halfWidth,
                y: anchor.y + constrained.y - halfHeight,
                width: calloutSize.width,
                height: calloutSize.height
            )
            guard candidate.intersects(destinationFrame) else { return constrained }

            let leftX = destinationFrame.minX - 12 - calloutSize.width
            let rightX = destinationFrame.maxX + 12
            if leftX >= usableBounds.minX {
                candidate.origin.x = leftX
            } else if rightX + calloutSize.width <= usableBounds.maxX {
                candidate.origin.x = rightX
            } else {
                let aboveY = destinationFrame.minY - 12 - calloutSize.height
                candidate.origin.y = aboveY >= usableBounds.minY
                    ? aboveY
                    : min(destinationFrame.maxY + 12, usableBounds.maxY - calloutSize.height)
            }
            constrained = AviationMapCalloutOffset(
                x: candidate.midX - anchor.x,
                y: candidate.midY - anchor.y
            )
            return constrained
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
    let targetID: NavigationTimingTargetKey
    let plannedElapsedSeconds: Int
    let waypointName: String
    let plannedDurationText: String
    let committedETAText: String?
    let committedETASeconds: Int?
    let referenceText: String?

    init(
        waypoint: AviationMapWaypoint,
        reference: AviationMapVORDMEReference?,
        targetID: NavigationTimingTargetKey,
        plannedElapsedSeconds: Int,
        plannedDurationText: String,
        committedETASeconds: Int?
    ) {
        waypointName = waypoint.name
        self.targetID = targetID
        self.plannedElapsedSeconds = plannedElapsedSeconds
        self.plannedDurationText = plannedDurationText
        self.committedETASeconds = committedETASeconds
        committedETAText = committedETASeconds.map(AviationMapSymbology.formatDuration)
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
    private let onSelect: (NavigationTimingTargetKey) -> Void
    private let targetID: NavigationTimingTargetKey
    private let isExpanded: Bool

    init(
        annotation: DestinationCalloutAnnotation,
        visualStyle: AviationMapVisualStyle,
        offset: AviationMapCalloutOffset,
        context: AviationMapTimingTargetContext?,
        onSelect: @escaping (NavigationTimingTargetKey) -> Void,
        onAdjust: @escaping (NavigationTimingTargetKey, Int) -> Void,
        onCommit: @escaping (NavigationTimingTargetKey) -> Void,
        onEdit: @escaping (NavigationTimingTargetKey) -> Void,
        onShowCheck: @escaping (NavigationTimingTargetKey) -> Void,
        onHideCheck: @escaping (NavigationTimingTargetKey) -> Void,
        offsetHandler: @escaping OffsetHandler
    ) {
        self.offset = offset
        self.offsetHandler = offsetHandler
        self.onSelect = onSelect
        targetID = annotation.targetID
        isExpanded = context != nil
        super.init(reuseIdentifier: "destination-eta-callout")

        clipsToBounds = false
        layer.masksToBounds = false

        leader.strokeColor = visualStyle.etaCalloutBorderColor
            .withAlphaComponent(visualStyle.etaCalloutBorderOpacity).cgColor
        leader.lineWidth = visualStyle.etaCalloutBorderWidth
        leader.fillColor = UIColor.clear.cgColor
        layer.insertSublayer(leader, at: 0)

        let target = AviationMapETATarget(
            id: annotation.targetID,
            name: annotation.waypointName,
            plannedElapsedSeconds: annotation.plannedElapsedSeconds,
            committedETASeconds: annotation.committedETASeconds
        )
        let content = TimingTargetCalloutContent(
            target: context?.target ?? target,
            context: context,
            visualStyle: visualStyle,
            accentColor: visualStyle.etaCalloutBorderColor,
            collapsedReferenceText: annotation.referenceText,
            onCollapseOrExpand: { onSelect(annotation.targetID) },
            onAdjust: onAdjust,
            onCommit: onCommit,
            onEdit: onEdit,
            onShowCheck: onShowCheck,
            onHideCheck: onHideCheck
        )
        let host = UIHostingController(rootView: content)
        host.view.backgroundColor = .clear
        let fittingSize = host.sizeThatFits(in: CGSize(width: 300, height: 560))
        frame = CGRect(origin: .zero, size: fittingSize)
        host.view.frame = bounds
        addSubview(host.view)

        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        pan.delegate = self
        addGestureRecognizer(pan)
        if !isExpanded {
            addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(selectTarget)))
        }
        isEnabled = true
        apply(offset: offset)
    }

    @objc private func selectTarget() { onSelect(targetID) }

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
        let mapView = sequence(first: host, next: { $0.superview })
            .first { $0 is MLNMapView } as? MLNMapView
        if gesture.state == .began {
            mapView?.isScrollEnabled = false
        }
        let translation = gesture.translation(in: host)
        let proposed = offset.translated(x: translation.x, y: translation.y)
        apply(offset: offsetHandler(proposed, bounds.size))
        gesture.setTranslation(.zero, in: host)
        if gesture.state == .ended || gesture.state == .cancelled || gesture.state == .failed {
            mapView?.isScrollEnabled = true
        }
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

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        guard gestureRecognizer is UIPanGestureRecognizer else { return true }
        if touch.view is UIControl { return false }
        return !isExpanded || touch.location(in: self).y <= 58
    }

    required init?(coder: NSCoder) {
        return nil
    }
}

private final class IdentificationPointSymbolAnnotation: MLNPointAnnotation {
    let point: AviationMapIdentificationPoint

    init(point: AviationMapIdentificationPoint) {
        self.point = point
        super.init()
        coordinate = CLLocationCoordinate2D(
            latitude: point.coordinate.latitude,
            longitude: point.coordinate.longitude
        )
    }

    required init?(coder: NSCoder) { nil }
}

private final class IdentificationPointLabelAnnotation: MLNPointAnnotation {
    let point: AviationMapIdentificationPoint

    init(point: AviationMapIdentificationPoint) {
        self.point = point
        super.init()
        coordinate = CLLocationCoordinate2D(
            latitude: point.coordinate.latitude,
            longitude: point.coordinate.longitude
        )
    }

    required init?(coder: NSCoder) { nil }
}

private final class IdentificationPointSymbolAnnotationView: MLNAnnotationView {
    private let pointID: IdentificationPointKey
    private let onSelect: (IdentificationPointKey) -> Void

    init(
        annotation: IdentificationPointSymbolAnnotation,
        visualStyle: AviationMapVisualStyle,
        onSelect: @escaping (IdentificationPointKey) -> Void
    ) {
        pointID = annotation.point.id
        self.onSelect = onSelect
        super.init(reuseIdentifier: "identification-symbol-\(annotation.point.id)")
        let size: CGFloat = 44
        frame = CGRect(origin: .zero, size: CGSize(width: size, height: size))
        let symbol = IdentificationPointEllipseView(
            isReached: annotation.point.isReached,
            visualStyle: visualStyle
        )
        symbol.frame = bounds
        addSubview(symbol)
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(selectPoint)))
        isEnabled = true
        accessibilityLabel = "\(annotation.point.name), \(AviationMapSymbology.formatDuration(annotation.point.plannedElapsedSeconds))"
        accessibilityTraits = .button
    }

    @objc private func selectPoint() { onSelect(pointID) }
    required init?(coder: NSCoder) { nil }
}

private final class IdentificationPointEllipseView: UIView {
    private let isReached: Bool
    private let visualStyle: AviationMapVisualStyle

    init(isReached: Bool, visualStyle: AviationMapVisualStyle) {
        self.isReached = isReached
        self.visualStyle = visualStyle
        super.init(frame: .zero)
        backgroundColor = .clear
        isOpaque = false
    }

    override func draw(_ rect: CGRect) {
        let ellipse = CGRect(
            x: bounds.midX - visualStyle.identificationPointEllipseWidth / 2,
            y: bounds.midY - visualStyle.identificationPointEllipseHeight / 2,
            width: visualStyle.identificationPointEllipseWidth,
            height: visualStyle.identificationPointEllipseHeight
        )
        let color = visualStyle.identificationPointColor
        color.withAlphaComponent(visualStyle.identificationPointEllipseFillOpacity).setFill()
        UIBezierPath(ovalIn: ellipse).fill()
        visualStyle.identificationPointEllipseHaloColor
            .withAlphaComponent(visualStyle.identificationPointEllipseHaloOpacity).setStroke()
        let outline = UIBezierPath(ovalIn: ellipse)
        outline.lineWidth = visualStyle.identificationPointEllipseHaloWidth
        outline.stroke()
        color.withAlphaComponent(visualStyle.identificationPointEllipseOutlineOpacity).setStroke()
        outline.lineWidth = visualStyle.identificationPointSymbolLineWidth
        outline.stroke()
        guard isReached else { return }
        let badgeDiameter = visualStyle.identificationPointReachedBadgeDiameter
        let badgeRect = CGRect(
            x: ellipse.maxX - badgeDiameter * 0.65,
            y: ellipse.minY - badgeDiameter * 0.35,
            width: badgeDiameter,
            height: badgeDiameter
        )
        visualStyle.identificationPointReachedColor.setFill()
        UIBezierPath(ovalIn: badgeRect).fill()
        UIColor.white.setStroke()
        let check = UIBezierPath()
        check.move(to: CGPoint(x: badgeRect.minX + 3, y: badgeRect.midY))
        check.addLine(to: CGPoint(x: badgeRect.minX + 5.5, y: badgeRect.maxY - 3))
        check.addLine(to: CGPoint(x: badgeRect.maxX - 2.5, y: badgeRect.minY + 3))
        check.lineWidth = 1.5
        check.lineCapStyle = .round
        check.lineJoinStyle = .round
        check.stroke()
    }

    required init?(coder: NSCoder) { nil }
}

private final class IdentificationPointLabelAnnotationView: MLNAnnotationView, UIGestureRecognizerDelegate {
    private var offset: AviationMapCalloutOffset
    private let pointID: IdentificationPointKey
    private let onSelect: (IdentificationPointKey) -> Void
    private let onOffsetChange: (AviationMapCalloutOffset, CGSize) -> AviationMapCalloutOffset
    private let leader = CAShapeLayer()
    private let isExpanded: Bool
    private var hostingController: UIHostingController<IdentificationPointCalloutContent>?

    init(
        annotation: IdentificationPointLabelAnnotation,
        visualStyle: AviationMapVisualStyle,
        offset: AviationMapCalloutOffset,
        context: AviationMapIdentificationContext?,
        targetContext: AviationMapTimingTargetContext?,
        onSelect: @escaping (IdentificationPointKey) -> Void,
        onReach: @escaping () -> Void,
        onAdjust: @escaping (NavigationTimingTargetKey, Int) -> Void,
        onCommit: @escaping (NavigationTimingTargetKey) -> Void,
        onEdit: @escaping (NavigationTimingTargetKey) -> Void,
        onRevise: @escaping (NavigationTimingTargetKey) -> Void,
        onShowCheck: @escaping (NavigationTimingTargetKey) -> Void,
        onHideCheck: @escaping (NavigationTimingTargetKey) -> Void,
        onOffsetChange: @escaping (AviationMapCalloutOffset, CGSize) -> AviationMapCalloutOffset
    ) {
        self.offset = offset
        pointID = annotation.point.id
        self.onSelect = onSelect
        self.onOffsetChange = onOffsetChange
        isExpanded = context != nil || targetContext != nil
        super.init(reuseIdentifier: "identification-label-\(annotation.point.id)")
        clipsToBounds = false
        layer.masksToBounds = false

        leader.strokeColor = visualStyle.identificationPointCalloutBorderColor
            .withAlphaComponent(visualStyle.identificationPointCalloutBorderOpacity).cgColor
        leader.lineWidth = visualStyle.identificationPointCalloutBorderWidth
        leader.fillColor = UIColor.clear.cgColor
        layer.insertSublayer(leader, at: 0)

        let content = IdentificationPointCalloutContent(
            point: annotation.point,
            context: context,
            targetContext: targetContext,
            visualStyle: visualStyle,
            onCollapseOrExpand: { onSelect(annotation.point.id) },
            onReach: onReach,
            onAdjust: onAdjust,
            onCommit: onCommit,
            onEdit: onEdit,
            onRevise: onRevise,
            onShowCheck: onShowCheck,
            onHideCheck: onHideCheck
        )
        let host = UIHostingController(rootView: content)
        hostingController = host
        host.view.backgroundColor = .clear
        let fittingSize = host.sizeThatFits(in: CGSize(width: 300, height: 560))
        frame = CGRect(origin: .zero, size: fittingSize)
        host.view.frame = bounds
        addSubview(host.view)
        self.offset = onOffsetChange(offset, bounds.size)

        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        pan.delegate = self
        addGestureRecognizer(pan)
        if !isExpanded {
            addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(selectPoint)))
        }
        isEnabled = true
        centerOffset = CGVector(dx: self.offset.x, dy: self.offset.y)
        updateLeader()
        accessibilityLabel = "\(annotation.point.name), planned time \(AviationMapSymbology.formatDuration(annotation.point.plannedElapsedSeconds))"
        accessibilityTraits = .button
    }

    @objc private func selectPoint() { onSelect(pointID) }

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard let host = superview else { return }
        let mapView = sequence(first: host, next: { $0.superview })
            .first { $0 is MLNMapView } as? MLNMapView
        if gesture.state == .began {
            mapView?.isScrollEnabled = false
        }
        let translation = gesture.translation(in: host)
        offset = onOffsetChange(
            offset.translated(x: translation.x, y: translation.y),
            bounds.size
        )
        centerOffset = CGVector(dx: offset.x, dy: offset.y)
        center = CGPoint(x: center.x + translation.x, y: center.y + translation.y)
        updateLeader()
        gesture.setTranslation(.zero, in: host)
        if gesture.state == .ended || gesture.state == .cancelled || gesture.state == .failed {
            mapView?.isScrollEnabled = true
        }
    }

    private func updateLeader() {
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let anchor = CGPoint(x: center.x - offset.x, y: center.y - offset.y)
        let delta = CGPoint(x: anchor.x - center.x, y: anchor.y - center.y)
        let horizontalScale = delta.x == 0 ? .greatestFiniteMagnitude : bounds.width / 2 / abs(delta.x)
        let verticalScale = delta.y == 0 ? .greatestFiniteMagnitude : bounds.height / 2 / abs(delta.y)
        let scale = min(horizontalScale, verticalScale)
        let path = UIBezierPath()
        path.move(to: CGPoint(x: center.x + delta.x * scale, y: center.y + delta.y * scale))
        path.addLine(to: anchor)
        leader.path = path.cgPath
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool { false }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        guard gestureRecognizer is UIPanGestureRecognizer else { return true }
        if touch.view is UIControl { return false }
        return !isExpanded || touch.location(in: self).y <= 58
    }

    required init?(coder: NSCoder) { nil }
}

private struct TimingTargetCalloutContent: View {
    let target: AviationMapETATarget
    let context: AviationMapTimingTargetContext?
    let visualStyle: AviationMapVisualStyle
    let accentColor: UIColor
    let collapsedReferenceText: String?
    let onCollapseOrExpand: () -> Void
    let onAdjust: (NavigationTimingTargetKey, Int) -> Void
    let onCommit: (NavigationTimingTargetKey) -> Void
    let onEdit: (NavigationTimingTargetKey) -> Void
    let onShowCheck: (NavigationTimingTargetKey) -> Void
    let onHideCheck: (NavigationTimingTargetKey) -> Void

    var body: some View {
        VStack(alignment: context == nil ? .center : .leading, spacing: context == nil ? 1 : 9) {
            if let context {
                Button(action: onCollapseOrExpand) {
                    HStack {
                        Text(target.name).font(.headline).lineLimit(1)
                        Spacer()
                        Image(systemName: "chevron.up")
                    }
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                if context.pilotETAState.isEditing {
                    timingRow("PLAN ETA", target.plannedElapsedSeconds, strong: false)
                    timingRow("NEW ETA", context.pilotETAState.draftSeconds, strong: true)
                    HStack(spacing: 10) {
                        adjustmentButton("−5s", -visualStyle.etaAdjustmentStepSeconds)
                        adjustmentButton("+5s", visualStyle.etaAdjustmentStepSeconds)
                    }
                    Button(context.pilotETAState.committedSeconds == nil ? "Set new ETA" : "Update ETA") {
                        onCommit(target.id)
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .buttonStyle(.borderedProminent)
                } else if let committed = context.pilotETAState.committedSeconds {
                    timingRow("ETA", committed, strong: true)
                    timingRow("PLAN", target.plannedElapsedSeconds, strong: false)
                    Label("Set", systemImage: "checkmark").font(.caption).foregroundStyle(.secondary)
                    Button("Edit ETA") { onEdit(target.id) }
                        .frame(maxWidth: .infinity, minHeight: 44).buttonStyle(.bordered)
                    if context.pilotETAState.isCheckResultVisible, let reference = context.timingReferenceSeconds {
                        timingRow("YOUR ETA", committed, strong: true)
                        timingRow("TIMING REFERENCE", reference, strong: false)
                        signedTimingRow("DIFFERENCE", committed - reference)
                        Text("If the observed pace continues").font(.caption).foregroundStyle(.secondary)
                        Button("Hide check") { onHideCheck(target.id) }
                            .frame(maxWidth: .infinity, minHeight: 44).buttonStyle(.plain)
                    } else if context.timingReferenceSeconds != nil {
                        Button("Cross-check calculation") { onShowCheck(target.id) }
                            .frame(maxWidth: .infinity, minHeight: 44).buttonStyle(.bordered)
                    }
                }
            } else {
                Text(target.name).font(.caption.weight(.semibold)).lineLimit(1)
                Text(AviationMapSymbology.formatDuration(target.committedETASeconds ?? target.plannedElapsedSeconds))
                    .font(.headline.monospacedDigit()).bold()
                if target.committedETASeconds != nil {
                    Text("ETA").font(.caption.weight(.bold))
                    Text("PLAN \(AviationMapSymbology.formatDuration(target.plannedElapsedSeconds))")
                        .font(.caption2).foregroundStyle(.secondary).monospacedDigit()
                }
                if let collapsedReferenceText {
                    Text(collapsedReferenceText).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                }
            }
        }
        .padding(context == nil ? 6 : 12)
        .frame(width: context == nil ? 154 : 286)
        .background(
            Color(uiColor: visualStyle.etaCalloutBackgroundColor)
                .opacity(context == nil ? visualStyle.etaCalloutBackgroundOpacity : visualStyle.etaExpandedCalloutBackgroundOpacity),
            in: RoundedRectangle(cornerRadius: 7)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 7).stroke(
                Color(uiColor: accentColor).opacity(visualStyle.etaCalloutBorderOpacity),
                lineWidth: visualStyle.etaCalloutBorderWidth
            )
        }
        .accessibilityIdentifier("timing-target-\(target.id.targetID.uuidString)")
    }

    private func adjustmentButton(_ title: String, _ delta: Int) -> some View {
        Button(title) { onAdjust(target.id, delta) }
            .font(.headline.monospacedDigit())
            .frame(maxWidth: .infinity, minHeight: 44)
            .buttonStyle(.bordered)
            .buttonRepeatBehavior(.enabled)
    }

    private func timingRow(_ title: String, _ seconds: Int, strong: Bool) -> some View {
        HStack { Text(title).foregroundStyle(.secondary); Spacer(); Text(AviationMapSymbology.formatDuration(seconds)).monospacedDigit().fontWeight(strong ? .bold : .semibold) }
            .font(.subheadline)
    }

    private func signedTimingRow(_ title: String, _ seconds: Int) -> some View {
        HStack { Text(title).foregroundStyle(.secondary); Spacer(); Text((seconds >= 0 ? "+" : "−") + AviationMapSymbology.formatDuration(abs(seconds))).monospacedDigit().bold() }
            .font(.subheadline)
    }
}

private struct IdentificationPointCalloutContent: View {
    let point: AviationMapIdentificationPoint
    let context: AviationMapIdentificationContext?
    let targetContext: AviationMapTimingTargetContext?
    let visualStyle: AviationMapVisualStyle
    let onCollapseOrExpand: () -> Void
    let onReach: () -> Void
    let onAdjust: (NavigationTimingTargetKey, Int) -> Void
    let onCommit: (NavigationTimingTargetKey) -> Void
    let onEdit: (NavigationTimingTargetKey) -> Void
    let onRevise: (NavigationTimingTargetKey) -> Void
    let onShowCheck: (NavigationTimingTargetKey) -> Void
    let onHideCheck: (NavigationTimingTargetKey) -> Void

    @ViewBuilder
    var body: some View {
        if let targetContext {
            TimingTargetCalloutContent(
                target: targetContext.target,
                context: targetContext,
                visualStyle: visualStyle,
                accentColor: visualStyle.identificationPointCalloutBorderColor,
                collapsedReferenceText: nil,
                onCollapseOrExpand: onCollapseOrExpand,
                onAdjust: onAdjust,
                onCommit: onCommit,
                onEdit: onEdit,
                onShowCheck: onShowCheck,
                onHideCheck: onHideCheck
            )
        } else {
            observationCallout
        }
    }

    private var observationCallout: some View {
        Group {
            if let context { expanded(context) } else { collapsed }
        }
        .padding(context == nil ? 6 : 12)
        .frame(width: context == nil ? 154 : 286)
        .background(
            Color(uiColor: visualStyle.identificationPointCalloutBackgroundColor)
                .opacity(context == nil
                    ? visualStyle.identificationPointCollapsedCalloutBackgroundOpacity
                    : visualStyle.identificationPointExpandedCalloutBackgroundOpacity),
            in: RoundedRectangle(cornerRadius: 7)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 7)
                .stroke(
                    Color(uiColor: visualStyle.identificationPointCalloutBorderColor)
                        .opacity(visualStyle.identificationPointCalloutBorderOpacity),
                    lineWidth: visualStyle.identificationPointCalloutBorderWidth
                )
        }
    }

    private var collapsed: some View {
        VStack(spacing: 0) {
            Text(point.name).font(.caption.weight(.semibold)).lineLimit(1)
            Text(AviationMapSymbology.formatDuration(point.committedETASeconds ?? point.plannedElapsedSeconds))
                .font(.headline.monospacedDigit()).bold()
            if point.committedETASeconds != nil {
                Text("ETA · PLAN \(AviationMapSymbology.formatDuration(point.plannedElapsedSeconds))")
                    .font(.caption2).foregroundStyle(.secondary).monospacedDigit()
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func expanded(_ context: AviationMapIdentificationContext) -> some View {
        let operationalState = point.operationalState
        return VStack(alignment: .leading, spacing: 9) {
            Button(action: onCollapseOrExpand) {
                HStack {
                    Text("IDENTIFICATION POINT").font(.caption.weight(.bold)).tracking(0.7)
                    Spacer()
                    Image(systemName: "chevron.up")
                }
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            Text(operationalState.isReached ? "\(point.name) · Reached" : point.name).font(.headline)
            if !operationalState.isReached, let committed = operationalState.committedETASeconds {
                timingRow("ETA", committed, strong: true)
                timingRow("PLAN", operationalState.plannedElapsedSeconds, strong: false)
            } else {
                timingRow(operationalState.isReached ? "PLAN" : "PLAN ETA", operationalState.plannedElapsedSeconds, strong: false)
            }

            if operationalState.isReached, let actual = context.actualElapsedSeconds {
                timingRow("ACTUAL", actual, strong: false)
                signedTimingRow("Δ", actual - point.plannedElapsedSeconds)
            }

            if operationalState.canMarkReached {
                Button("Point Reached", systemImage: "checkmark", action: onReach)
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("identification-point-reached")
                Button("Edit ETA") {
                    let targetKey = NavigationTimingTargetKey(
                        legID: point.id.legID,
                        kind: .identificationPoint,
                        targetID: point.id.identificationPointID
                    )
                    if operationalState.committedETASeconds != nil { onEdit(targetKey) }
                    onRevise(targetKey)
                }
                .font(.subheadline)
                .frame(maxWidth: .infinity, minHeight: 44)
                .buttonStyle(.plain)
                .accessibilityIdentifier("edit-identification-point-eta")
            } else if let target = context.nextTarget,
                      true {
                Divider()
                Text("NEXT TARGET · \(target.name)")
                    .font(.caption.weight(.bold)).foregroundStyle(.secondary)
                if let committed = target.committedETASeconds {
                    timingRow("ETA", committed, strong: true)
                    timingRow("PLAN", target.plannedElapsedSeconds, strong: false)
                } else {
                    timingRow("PLAN ETA", target.plannedElapsedSeconds, strong: false)
                }
                Button(target.committedETASeconds == nil ? "Revise next ETA" : "Edit next ETA") {
                    if target.committedETASeconds != nil { onEdit(target.id) }
                    onRevise(target.id)
                }
                .frame(maxWidth: .infinity, minHeight: 44)
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private func timingRow(_ title: String, _ seconds: Int, strong: Bool) -> some View {
        HStack {
            Text(title).foregroundStyle(.secondary)
            Spacer()
            Text(AviationMapSymbology.formatDuration(seconds))
                .monospacedDigit()
                .fontWeight(strong ? .bold : .semibold)
        }
        .font(.subheadline)
    }

    private func signedTimingRow(_ title: String, _ seconds: Int) -> some View {
        HStack {
            Text(title).foregroundStyle(.secondary)
            Spacer()
            Text(signedDuration(seconds)).monospacedDigit().bold()
        }
        .font(.subheadline)
    }

    private func signedDuration(_ seconds: Int) -> String {
        (seconds >= 0 ? "+" : "−") + AviationMapSymbology.formatDuration(abs(seconds))
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
