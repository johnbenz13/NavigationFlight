import CoreLocation
import MapLibre
import SwiftUI
import UIKit

enum AviationMapFocusMode: Equatable, Sendable {
    case leg
    case waypoint
    case overview
    case timingTarget(AviationMapCoordinate)
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
    @Binding var vorDMECalloutOffset: AviationMapCalloutOffset
    @Binding var identificationPointCalloutOffsets: [IdentificationPointKey: AviationMapCalloutOffset]
    let identificationContext: AviationMapIdentificationContext?
    let timingTargetContext: AviationMapTimingTargetContext?
    @Binding var preservedCamera: AviationMapCameraState?
    @Binding var isCameraUserControlled: Bool
    let onSelectIdentificationPoint: (IdentificationPointKey) -> Void
    let onSelectTimingTarget: (NavigationTimingTargetKey) -> Void
    let onDismissCallout: () -> Void
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
        vorDMECalloutOffset: Binding<AviationMapCalloutOffset>,
        identificationPointCalloutOffsets: Binding<[IdentificationPointKey: AviationMapCalloutOffset]>,
        identificationContext: AviationMapIdentificationContext?,
        timingTargetContext: AviationMapTimingTargetContext?,
        preservedCamera: Binding<AviationMapCameraState?>,
        isCameraUserControlled: Binding<Bool>,
        onSelectIdentificationPoint: @escaping (IdentificationPointKey) -> Void,
        onSelectTimingTarget: @escaping (NavigationTimingTargetKey) -> Void,
        onDismissCallout: @escaping () -> Void,
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
        _vorDMECalloutOffset = vorDMECalloutOffset
        _identificationPointCalloutOffsets = identificationPointCalloutOffsets
        self.identificationContext = identificationContext
        self.timingTargetContext = timingTargetContext
        _preservedCamera = preservedCamera
        _isCameraUserControlled = isCameraUserControlled
        self.onSelectIdentificationPoint = onSelectIdentificationPoint
        self.onSelectTimingTarget = onSelectTimingTarget
        self.onDismissCallout = onDismissCallout
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
            vorDMECalloutOffset: $vorDMECalloutOffset,
            identificationPointCalloutOffsets: $identificationPointCalloutOffsets,
            identificationContext: identificationContext,
            timingTargetContext: timingTargetContext,
            initialCamera: preservedCamera,
            preservedCamera: $preservedCamera,
            isCameraUserControlled: $isCameraUserControlled,
            onSelectIdentificationPoint: onSelectIdentificationPoint,
            onSelectTimingTarget: onSelectTimingTarget,
            onDismissCallout: onDismissCallout,
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
        mapView.minimumZoomLevel = 8
        mapView.maximumZoomLevel = 13
        mapView.logoView.isHidden = true
        mapView.attributionButton.isHidden = true
        let backgroundTap = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.didTapMapBackground)
        )
        backgroundTap.cancelsTouchesInView = false
        backgroundTap.delegate = context.coordinator
        mapView.addGestureRecognizer(backgroundTap)
        return mapView
    }

    func updateUIView(_ mapView: MLNMapView, context: Context) {
        context.coordinator.updateHandlers(
            onSelectIdentificationPoint: onSelectIdentificationPoint,
            onSelectTimingTarget: onSelectTimingTarget,
            onDismissCallout: onDismissCallout,
            onReachIdentificationPoint: onReachIdentificationPoint,
            onAdjustPilotETA: onAdjustPilotETA,
            onCommitPilotETA: onCommitPilotETA,
            onEditPilotETA: onEditPilotETA,
            onShowPilotETACheck: onShowPilotETACheck,
            onHidePilotETACheck: onHidePilotETACheck
        )
        context.coordinator.update(
            presentation: presentation,
            legState: legState,
            identificationContext: identificationContext,
            timingTargetContext: timingTargetContext,
            focusRequest: focusRequest,
            mapView: mapView
        )
    }

    final class Coordinator: NSObject, MLNMapViewDelegate, UIGestureRecognizerDelegate {
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
        private let vorDMECalloutOffset: Binding<AviationMapCalloutOffset>
        private let identificationPointCalloutOffsets: Binding<[IdentificationPointKey: AviationMapCalloutOffset]>
        private var cachedIdentificationPointCalloutOffsets: [IdentificationPointKey: AviationMapCalloutOffset]
        private let initialCamera: AviationMapCameraState?
        private let preservedCamera: Binding<AviationMapCameraState?>
        private let isCameraUserControlled: Binding<Bool>
        private var styleIsReady = false
        private var endpointAnnotations: [MLNPointAnnotation] = []
        private weak var etaCalloutView: DestinationCalloutAnnotationView?
        private weak var vorDMECalloutView: VORDMECalloutAnnotationView?
        private var onSelectIdentificationPoint: (IdentificationPointKey) -> Void
        private var onSelectTimingTarget: (NavigationTimingTargetKey) -> Void
        private var onDismissCallout: () -> Void
        private var onReachIdentificationPoint: () -> Void
        private var onAdjustPilotETA: (NavigationTimingTargetKey, Int) -> Void
        private var onCommitPilotETA: (NavigationTimingTargetKey) -> Void
        private var onEditPilotETA: (NavigationTimingTargetKey) -> Void
        private var onShowPilotETACheck: (NavigationTimingTargetKey) -> Void
        private var onHidePilotETACheck: (NavigationTimingTargetKey) -> Void

        init(
            presentation: AviationMapPresentation,
            legState: FlightSession.LegState,
            focusRequest: AviationMapFocusRequest,
            chartURL: URL?,
            visualStyle: AviationMapVisualStyle,
            etaCalloutOffset: Binding<AviationMapCalloutOffset>,
            vorDMECalloutOffset: Binding<AviationMapCalloutOffset>,
            identificationPointCalloutOffsets: Binding<[IdentificationPointKey: AviationMapCalloutOffset]>,
            identificationContext: AviationMapIdentificationContext?,
            timingTargetContext: AviationMapTimingTargetContext?,
            initialCamera: AviationMapCameraState?,
            preservedCamera: Binding<AviationMapCameraState?>,
            isCameraUserControlled: Binding<Bool>,
            onSelectIdentificationPoint: @escaping (IdentificationPointKey) -> Void,
            onSelectTimingTarget: @escaping (NavigationTimingTargetKey) -> Void,
            onDismissCallout: @escaping () -> Void,
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
            self.vorDMECalloutOffset = vorDMECalloutOffset
            self.identificationPointCalloutOffsets = identificationPointCalloutOffsets
            cachedIdentificationPointCalloutOffsets = identificationPointCalloutOffsets.wrappedValue
            self.initialCamera = initialCamera
            self.preservedCamera = preservedCamera
            self.isCameraUserControlled = isCameraUserControlled
            self.onSelectIdentificationPoint = onSelectIdentificationPoint
            self.onSelectTimingTarget = onSelectTimingTarget
            self.onDismissCallout = onDismissCallout
            self.onReachIdentificationPoint = onReachIdentificationPoint
            self.onAdjustPilotETA = onAdjustPilotETA
            self.onCommitPilotETA = onCommitPilotETA
            self.onEditPilotETA = onEditPilotETA
            self.onShowPilotETACheck = onShowPilotETACheck
            self.onHidePilotETACheck = onHidePilotETACheck
        }

        func updateHandlers(
            onSelectIdentificationPoint: @escaping (IdentificationPointKey) -> Void,
            onSelectTimingTarget: @escaping (NavigationTimingTargetKey) -> Void,
            onDismissCallout: @escaping () -> Void,
            onReachIdentificationPoint: @escaping () -> Void,
            onAdjustPilotETA: @escaping (NavigationTimingTargetKey, Int) -> Void,
            onCommitPilotETA: @escaping (NavigationTimingTargetKey) -> Void,
            onEditPilotETA: @escaping (NavigationTimingTargetKey) -> Void,
            onShowPilotETACheck: @escaping (NavigationTimingTargetKey) -> Void,
            onHidePilotETACheck: @escaping (NavigationTimingTargetKey) -> Void
        ) {
            self.onSelectIdentificationPoint = onSelectIdentificationPoint
            self.onSelectTimingTarget = onSelectTimingTarget
            self.onDismissCallout = onDismissCallout
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
                DispatchQueue.main.async { [weak self] in
                    self?.isCameraUserControlled.wrappedValue = true
                    self?.onDismissCallout()
                }
            }
        }

        @objc func didTapMapBackground() {
            onDismissCallout()
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            var view: UIView? = touch.view
            while let current = view {
                if current is UIControl || current is MLNAnnotationView {
                    return false
                }
                view = current.superview
            }
            return true
        }

        func mapView(_ mapView: MLNMapView, regionDidChangeAnimated animated: Bool) {
            guard styleIsReady else { return }
            let camera = AviationMapCameraState(
                center: AviationMapCoordinate(
                    latitude: mapView.centerCoordinate.latitude,
                    longitude: mapView.centerCoordinate.longitude
                ),
                zoomLevel: mapView.zoomLevel,
                direction: mapView.direction
            )
            DispatchQueue.main.async { [weak self, weak mapView] in
                guard let self, let mapView else { return }
                self.preservedCamera.wrappedValue = camera
                self.constrainEtaCallout(on: mapView)
                self.constrainVORDMECallout(on: mapView)
                self.constrainIdentificationPointCallouts(on: mapView)
            }
        }

        func mapView(_ mapView: MLNMapView, viewFor annotation: MLNAnnotation) -> MLNAnnotationView? {
            if let annotation = annotation as? VORDMECalloutAnnotation {
                let callout = VORDMECalloutAnnotationView(
                    annotation: annotation,
                    offset: vorDMECalloutOffset.wrappedValue
                ) { [weak self, weak mapView] proposed, size in
                    guard let self, let mapView else { return proposed }
                    let constrained = self.constrainedVORDMECalloutOffset(proposed, size: size, on: mapView)
                    DispatchQueue.main.async { [weak self] in
                        self?.vorDMECalloutOffset.wrappedValue = constrained
                    }
                    return constrained
                }
                vorDMECalloutView = callout
                return callout
            }
            if let annotation = annotation as? EndpointAnnotation {
                let identifier = "endpoint-\(annotation.identifier.uuidString)"
                let destinationTargetID = presentation.destinationTarget.id
                return EndpointAnnotationView(
                    annotation: annotation,
                    reuseIdentifier: identifier,
                    visualStyle: visualStyle,
                    onSelectDestination: { [weak self] in
                        self?.onSelectTimingTarget(destinationTargetID)
                    }
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
                    DispatchQueue.main.async { [weak self] in
                        self?.etaCalloutOffset.wrappedValue = constrained
                    }
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
                    DispatchQueue.main.async { [weak self] in
                        self?.identificationPointCalloutOffsets.wrappedValue[annotation.point.id] = constrained
                    }
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
                case .timingTarget(let coordinate):
                    focusTimingTarget(coordinate, on: mapView)
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
            publishCameraOwnership(isUserControlled: false)
            if legState == .ready {
                fit(
                    [leg.from, leg.to],
                    on: mapView,
                    padding: UIEdgeInsets(top: 185, left: 105, bottom: 115, right: 190),
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
            publishCameraOwnership(isUserControlled: false)
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
            publishCameraOwnership(isUserControlled: false)
            fit(
                presentation.waypoints.map { $0.coordinate },
                on: mapView,
                padding: UIEdgeInsets(top: 120, left: 110, bottom: 85, right: 220),
                animated: true
            )
            mapView.setDirection(0, animated: true)
        }

        private func focusTimingTarget(_ target: AviationMapCoordinate, on mapView: MLNMapView) {
            publishCameraOwnership(isUserControlled: false)
            mapView.setCenter(
                coordinate(target),
                zoomLevel: mapView.zoomLevel,
                direction: mapView.direction,
                animated: !UIAccessibility.isReduceMotionEnabled
            )
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

        private func publishCameraOwnership(isUserControlled: Bool) {
            DispatchQueue.main.async { [weak self] in
                self?.isCameraUserControlled.wrappedValue = isUserControlled
            }
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
            if let destination = presentation.waypoints.first(where: { $0.role == .to }),
               let reference = presentation.endpointReferences.first(where: { $0.waypointID == destination.id }) {
                endpointAnnotations.append(VORDMECalloutAnnotation(waypoint: destination, reference: reference))
            }
            var destinationCallout: DestinationCalloutAnnotation?
            if timingTargetContext?.target.id == presentation.destinationTarget.id,
               let destination = presentation.waypoints.first(where: { $0.role == .to }) {
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
                let hasIdentificationCallout = identificationContext?.pointID == point.id
                let hasTimingCallout = timingTargetContext?.target.id.targetID == point.id.identificationPointID
                    && timingTargetContext?.target.id.legID == point.id.legID
                if hasIdentificationCallout || hasTimingCallout || point.status == .passedWithoutReport {
                    endpointAnnotations.append(IdentificationPointLabelAnnotation(point: point))
                }
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

        private func constrainVORDMECallout(on mapView: MLNMapView) {
            guard let vorDMECalloutView else { return }
            let constrained = constrainedVORDMECalloutOffset(
                vorDMECalloutOffset.wrappedValue,
                size: vorDMECalloutView.bounds.size,
                on: mapView
            )
            vorDMECalloutOffset.wrappedValue = constrained
            vorDMECalloutView.apply(offset: constrained)
        }

        private func constrainedVORDMECalloutOffset(
            _ proposed: AviationMapCalloutOffset,
            size: CGSize,
            on mapView: MLNMapView
        ) -> AviationMapCalloutOffset {
            guard let destination = presentation.activeFocusTarget else { return proposed }
            let anchor = mapView.convert(coordinate(destination), toPointTo: mapView)
            let bounds = mapView.bounds.inset(by: UIEdgeInsets(top: 125, left: 12, bottom: 12, right: 82))
            let halfWidth = size.width / 2
            let halfHeight = size.height / 2
            return AviationMapCalloutOffset(
                x: min(max(proposed.x, bounds.minX + halfWidth - anchor.x), bounds.maxX - halfWidth - anchor.x),
                y: min(max(proposed.y, bounds.minY + halfHeight - anchor.y), bounds.maxY - halfHeight - anchor.y)
            )
        }

        private func constrainIdentificationPointCallouts(on mapView: MLNMapView) {
            for annotation in endpointAnnotations {
                guard let label = annotation as? IdentificationPointLabelAnnotation,
                      let view = mapView.view(for: label) as? IdentificationPointLabelAnnotationView else {
                    continue
                }
                let proposed = cachedIdentificationPointCalloutOffsets[label.point.id]
                    ?? identificationPointCalloutOffsets.wrappedValue[label.point.id]
                    ?? visualStyle.defaultIdentificationPointCalloutOffset
                let constrained = constrainedIdentificationPointOffset(
                    proposed,
                    calloutSize: view.bounds.size,
                    point: label.point,
                    on: mapView
                )
                cachedIdentificationPointCalloutOffsets[label.point.id] = constrained
                identificationPointCalloutOffsets.wrappedValue[label.point.id] = constrained
                view.apply(offset: constrained)
            }
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

private final class VORDMECalloutAnnotation: MLNPointAnnotation {
    let titleText: String

    init(waypoint: AviationMapWaypoint, reference: AviationMapVORDMEReference) {
        let radial = Int(reference.magneticRadialFromDegrees.rounded())
        titleText = "\(reference.stationIdentifier) R-\(radial)°M · \(reference.slantRangeNauticalMiles.formatted(.number.precision(.fractionLength(1)))) NM"
        super.init()
        coordinate = CLLocationCoordinate2D(
            latitude: waypoint.coordinate.latitude,
            longitude: waypoint.coordinate.longitude
        )
    }

    required init?(coder: NSCoder) { nil }
}

private final class VORDMECalloutAnnotationView: MLNAnnotationView, UIGestureRecognizerDelegate {
    private var offset: AviationMapCalloutOffset
    private let offsetHandler: (AviationMapCalloutOffset, CGSize) -> AviationMapCalloutOffset

    init(
        annotation: VORDMECalloutAnnotation,
        offset: AviationMapCalloutOffset,
        offsetHandler: @escaping (AviationMapCalloutOffset, CGSize) -> AviationMapCalloutOffset
    ) {
        self.offset = offset
        self.offsetHandler = offsetHandler
        super.init(reuseIdentifier: "vor-dme-callout")
        frame = CGRect(origin: .zero, size: CGSize(width: 236, height: 52))
        backgroundColor = UIColor(red: 1, green: 1, blue: 1, alpha: 0.96)
        layer.cornerRadius = 12
        layer.masksToBounds = true

        let title = UILabel(frame: CGRect(x: 14, y: 8, width: 190, height: 18))
        title.font = .systemFont(ofSize: 13, weight: .bold)
        title.textColor = UIColor(red: 14 / 255, green: 17 / 255, blue: 22 / 255, alpha: 1)
        title.text = annotation.titleText
        addSubview(title)

        let subtitle = UILabel(frame: CGRect(x: 14, y: 28, width: 190, height: 14))
        subtitle.font = .systemFont(ofSize: 10, weight: .medium)
        subtitle.textColor = UIColor(red: 87 / 255, green: 94 / 255, blue: 107 / 255, alpha: 1)
        subtitle.text = "Planned VOR/DME confirmation"
        addSubview(subtitle)

        let handle = UIImageView(image: UIImage(systemName: "ellipsis"))
        handle.transform = CGAffineTransform(rotationAngle: .pi / 2)
        handle.tintColor = subtitle.textColor
        handle.contentMode = .scaleAspectFit
        handle.frame = CGRect(x: 208, y: 14, width: 16, height: 24)
        addSubview(handle)

        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        pan.delegate = self
        addGestureRecognizer(pan)
        isEnabled = true
        isAccessibilityElement = true
        accessibilityLabel = "VOR DME reference, \(annotation.titleText)"
        accessibilityHint = "Drag to reposition"
        apply(offset: offset)
    }

    func apply(offset: AviationMapCalloutOffset) {
        let previous = self.offset
        self.offset = offset
        centerOffset = CGVector(dx: offset.x, dy: offset.y)
        if superview != nil {
            center = CGPoint(x: center.x + offset.x - previous.x, y: center.y + offset.y - previous.y)
        }
    }

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard let host = superview else { return }
        let mapView = sequence(first: host, next: { $0.superview }).first { $0 is MLNMapView } as? MLNMapView
        if gesture.state == .began { mapView?.isScrollEnabled = false }
        let translation = gesture.translation(in: host)
        apply(offset: offsetHandler(offset.translated(x: translation.x, y: translation.y), bounds.size))
        gesture.setTranslation(.zero, in: host)
        if gesture.state == .ended || gesture.state == .cancelled || gesture.state == .failed {
            mapView?.isScrollEnabled = true
        }
    }

    required init?(coder: NSCoder) { nil }
}

private final class EndpointAnnotationView: MLNAnnotationView {
    private let onSelectDestination: () -> Void

    init(
        annotation: EndpointAnnotation,
        reuseIdentifier: String,
        visualStyle: AviationMapVisualStyle,
        onSelectDestination: @escaping () -> Void
    ) {
        self.onSelectDestination = onSelectDestination
        super.init(reuseIdentifier: reuseIdentifier)
        if annotation.role == .to {
            configureDestination(annotation, visualStyle: visualStyle)
            addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(selectDestination)))
            isEnabled = true
        } else {
            configureDeparture(annotation)
            isEnabled = false
        }
    }

    @objc private func selectDestination() {
        onSelectDestination()
    }

    private func configureDeparture(_ annotation: EndpointAnnotation) {
        let label = UILabel()
        label.numberOfLines = 1
        label.font = UIFontMetrics(forTextStyle: .caption1).scaledFont(
            for: .systemFont(ofSize: 12, weight: .bold)
        )
        label.textColor = .label
        label.layer.shadowColor = UIColor.white.cgColor
        label.layer.shadowRadius = 2
        label.layer.shadowOpacity = 1
        label.layer.shadowOffset = .zero
        label.text = annotation.waypointName
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
        let waypointLabel = UILabel()
        waypointLabel.font = UIFontMetrics(forTextStyle: .caption1).scaledFont(
            for: .systemFont(ofSize: 13, weight: .bold)
        )
        waypointLabel.textColor = .label
        waypointLabel.text = annotation.waypointName
        waypointLabel.layer.shadowColor = UIColor.white.cgColor
        waypointLabel.layer.shadowRadius = 2
        waypointLabel.layer.shadowOpacity = 1
        waypointLabel.layer.shadowOffset = .zero
        let waypointSize = waypointLabel.sizeThatFits(CGSize(width: 180, height: 20))
        frame = CGRect(origin: .zero, size: CGSize(width: diameter + 8 + waypointSize.width, height: diameter))
        let symbol = WaypointSymbolView(destination: true, visualStyle: visualStyle)
        symbol.frame = CGRect(x: 0, y: 0, width: diameter, height: diameter)
        addSubview(symbol)
        waypointLabel.frame = CGRect(x: diameter + 8, y: bounds.midY - 10, width: waypointSize.width, height: 20)
        addSubview(waypointLabel)
        centerOffset = CGVector(dx: bounds.midX - diameter / 2, dy: bounds.midY - diameter / 2)
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
        let inset: CGFloat = destination ? 5 : 3
        let circle = bounds.insetBy(dx: inset, dy: inset)
        let fillOpacity = destination ? visualStyle.destinationWaypointFillOpacity : 0.88
        let fillColor = destination ? visualStyle.destinationWaypointFillColor : UIColor.systemBackground
        fillColor.withAlphaComponent(fillOpacity).setFill()
        if !destination { context?.fillEllipse(in: circle) }
        let strokeColor = destination ? visualStyle.destinationWaypointStrokeColor : UIColor.label
        let strokeOpacity = destination ? visualStyle.destinationWaypointStrokeOpacity : 1
        strokeColor.withAlphaComponent(strokeOpacity).setStroke()
        context?.setLineWidth(destination ? visualStyle.destinationWaypointStrokeWidth : 2)
        if destination {
            let triangle = UIBezierPath()
            triangle.move(to: CGPoint(x: bounds.midX, y: circle.minY))
            triangle.addLine(to: CGPoint(x: circle.maxX, y: circle.maxY))
            triangle.addLine(to: CGPoint(x: circle.minX, y: circle.maxY))
            triangle.close()
            triangle.lineWidth = visualStyle.destinationWaypointStrokeWidth
            triangle.stroke()
            return
        }
        context?.strokeEllipse(in: circle)
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
        leader.isHidden = !isExpanded
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
        frame = CGRect(origin: .zero, size: CGSize(width: 100, height: 44))
        let symbolColor: UIColor = switch annotation.point.status {
            case .future: visualStyle.identificationPointColor
            case .reached: visualStyle.identificationPointReachedColor
            case .passedWithoutReport: visualStyle.identificationPointPassedColor
        }
        let symbol = IdentificationPointEllipseView(
            color: symbolColor,
            visualStyle: visualStyle
        )
        symbol.frame = CGRect(x: 0, y: 0, width: 44, height: 44)
        addSubview(symbol)
        let label = UILabel(frame: CGRect(x: 46, y: 12, width: 50, height: 20))
        label.font = UIFontMetrics(forTextStyle: .caption1).scaledFont(
            for: .systemFont(ofSize: 13, weight: .bold)
        )
        label.textColor = .label
        label.text = annotation.point.name.replacingOccurrences(of: "IP", with: "IP ")
        label.layer.shadowColor = UIColor.white.cgColor
        label.layer.shadowRadius = 2
        label.layer.shadowOpacity = 1
        label.layer.shadowOffset = .zero
        addSubview(label)
        centerOffset = CGVector(dx: 28, dy: 0)
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(selectPoint)))
        isEnabled = true
        accessibilityLabel = switch annotation.point.status {
        case .future:
            "\(annotation.point.name), future target, planned ETA \(AviationMapSymbology.formatDuration(annotation.point.plannedElapsedSeconds))"
        case .reached:
            "\(annotation.point.name), reached"
        case .passedWithoutReport:
            "\(annotation.point.name), passed without report, no Actual ETA"
        }
        accessibilityTraits = .button
    }

    @objc private func selectPoint() { onSelect(pointID) }
    required init?(coder: NSCoder) { nil }
}

private final class IdentificationPointEllipseView: UIView {
    private let color: UIColor
    private let visualStyle: AviationMapVisualStyle

    init(color: UIColor, visualStyle: AviationMapVisualStyle) {
        self.color = color
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

        let leaderColor: UIColor = switch annotation.point.status {
        case .future: visualStyle.identificationPointColor
        case .reached: visualStyle.identificationPointReachedColor
        case .passedWithoutReport: visualStyle.identificationPointPassedColor
        }
        leader.strokeColor = leaderColor
            .withAlphaComponent(visualStyle.identificationPointCalloutBorderOpacity).cgColor
        leader.lineWidth = visualStyle.identificationPointCalloutBorderWidth
        leader.fillColor = UIColor.clear.cgColor
        leader.isHidden = !isExpanded
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

    func apply(offset: AviationMapCalloutOffset) {
        self.offset = offset
        centerOffset = CGVector(dx: offset.x, dy: offset.y)
        updateLeader()
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
        let isFocusedRevision = context?.pilotETAState.isEditing == true && context?.observationBasis != nil
        VStack(alignment: context == nil ? .center : .leading, spacing: context == nil ? 1 : 9) {
            if let context {
                if isFocusedRevision {
                    focusedRevisionEditor(context)
                } else {
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
        .padding(context == nil ? 6 : (isFocusedRevision ? 0 : 12))
        .frame(
            width: context == nil ? (collapsedReferenceText == nil ? 154 : 236) : (isFocusedRevision ? 338 : 286),
            height: isFocusedRevision ? 352 : nil
        )
        .background(
            Color(uiColor: visualStyle.etaCalloutBackgroundColor)
                .opacity(context == nil ? visualStyle.etaCalloutBackgroundOpacity : visualStyle.etaExpandedCalloutBackgroundOpacity),
            in: RoundedRectangle(cornerRadius: isFocusedRevision ? 18 : 7)
        )
        .overlay {
            RoundedRectangle(cornerRadius: isFocusedRevision ? 18 : 7).stroke(
                (isFocusedRevision ? Color(uiColor: .systemGray4) : Color(uiColor: accentColor))
                    .opacity(visualStyle.etaCalloutBorderOpacity),
                lineWidth: isFocusedRevision ? 1 : visualStyle.etaCalloutBorderWidth
            )
        }
        .shadow(color: .black.opacity(isFocusedRevision ? 0.18 : 0), radius: 8, y: 5)
        .accessibilityIdentifier("timing-target-\(target.id.targetID.uuidString)")
    }

    private func focusedRevisionEditor(_ context: AviationMapTimingTargetContext) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("\(target.name.uppercased()) · REVISE NEXT ETA")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color(uiColor: visualStyle.primaryActionColor))
                .frame(height: 20, alignment: .leading)
            Text("Draft from Revised ETA")
                .font(.body.weight(.semibold))
                .frame(height: 20, alignment: .leading)
                .padding(.top, 2)
            Divider().padding(.top, 8)
            Text("OBSERVATION BASIS")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(height: 20, alignment: .leading)
                .padding(.top, 12)
            Text(context.observationBasis ?? "")
                .font(.footnote)
                .frame(height: 20, alignment: .leading)
            Text("DRAFT REVISED ETA")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color(uiColor: visualStyle.primaryActionColor))
                .frame(height: 20, alignment: .leading)
                .padding(.top, 15)
            HStack(spacing: 0) {
                stepperButton("−5s", delta: -visualStyle.etaAdjustmentStepSeconds)
                Text(AviationMapSymbology.formatDuration(context.pilotETAState.draftSeconds))
                    .font(.title2.weight(.bold).monospacedDigit())
                    .frame(maxWidth: .infinity)
                stepperButton("+5s", delta: visualStyle.etaAdjustmentStepSeconds)
            }
            .frame(height: 62)
            .background(Color(uiColor: .systemBlue).opacity(0.09), in: RoundedRectangle(cornerRadius: 14))
            .overlay { RoundedRectangle(cornerRadius: 14).stroke(Color(uiColor: .systemGray4)) }

            HStack(spacing: 10) {
                editorButton("Cancel", foreground: .primary, background: Color(uiColor: .systemGray6)) {
                    onCollapseOrExpand()
                }
                editorButton("Commit Revision", foreground: .white, background: Color(uiColor: visualStyle.primaryActionColor)) {
                    onCommit(target.id)
                }
            }
            .padding(.top, 17)
            editorButton("Check", foreground: .white, background: Color(uiColor: visualStyle.cockpitProgressionActionBackgroundColor)) {
                onCommit(target.id)
                onShowCheck(target.id)
            }
            .padding(.top, 12)
        }
        .padding(.horizontal, 17)
        .padding(.top, 15)
        .padding(.bottom, 17)
    }

    private func stepperButton(_ title: LocalizedStringKey, delta: Int) -> some View {
        Button(title) { onAdjust(target.id, delta) }
            .font(.title3.weight(.semibold).monospacedDigit())
            .foregroundStyle(Color(uiColor: visualStyle.primaryActionColor))
            .frame(width: 82, height: 62)
            .buttonStyle(.plain)
    }

    private func editorButton(
        _ title: LocalizedStringKey,
        foreground: Color,
        background: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(foreground)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.plain)
        .background(background, in: RoundedRectangle(cornerRadius: 12))
    }

    private func adjustmentButton(_ title: String, _ delta: Int) -> some View {
        Button(title) { onAdjust(target.id, delta) }
            .font(.headline.monospacedDigit())
            .frame(maxWidth: .infinity, minHeight: 44)
            .buttonStyle(.bordered)
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
        let isPassed = point.status == .passedWithoutReport
        let isFutureExpanded = context != nil && point.status == .future
        let isReachedExpanded = context != nil && point.status == .reached
        let isDesignedExpanded = isFutureExpanded || isReachedExpanded
        return Group {
            if let context {
                if isFutureExpanded && context.reportError == nil {
                    futureCallout(point.operationalState)
                } else if isReachedExpanded,
                          context.reportError == nil,
                          let actual = context.actualElapsedSeconds {
                    reachedResultCallout(context: context, actual: actual)
                } else {
                    expanded(context)
                }
            } else {
                collapsed
            }
        }
        .padding(context == nil ? (isPassed ? 8 : 2) : (isDesignedExpanded ? 0 : 12))
        .frame(
            width: context == nil ? (isPassed ? 180 : 42) : (isFutureExpanded ? 310 : (isReachedExpanded ? 330 : 286)),
            height: isFutureExpanded ? 218 : (isReachedExpanded ? 294 : nil)
        )
        .background(
            Color(uiColor: visualStyle.identificationPointCalloutBackgroundColor)
                .opacity(context == nil
                    ? (isPassed ? 0.88 : 0)
                    : visualStyle.identificationPointExpandedCalloutBackgroundOpacity),
            in: RoundedRectangle(cornerRadius: isDesignedExpanded ? 18 : 7)
        )
        .overlay {
            RoundedRectangle(cornerRadius: isDesignedExpanded ? 18 : 7)
                .stroke(
                    (isDesignedExpanded ? Color(uiColor: .systemGray4) : Color(uiColor: calloutAccentColor))
                        .opacity(context == nil && !isPassed ? 0 : visualStyle.identificationPointCalloutBorderOpacity),
                    lineWidth: isDesignedExpanded ? 1 : visualStyle.identificationPointCalloutBorderWidth
                )
        }
        .shadow(color: .black.opacity(isDesignedExpanded ? 0.18 : 0), radius: 8, y: 5)
    }

    private func futureCallout(
        _ operationalState: AviationMapIdentificationPointOperationalState
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(kicker(for: operationalState))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color(uiColor: visualStyle.primaryActionColor))
                .frame(height: 20, alignment: .leading)

            Text("Planned ETA \(AviationMapSymbology.formatDuration(operationalState.plannedElapsedSeconds))")
                .font(.body.weight(.semibold).monospacedDigit())
                .frame(height: 20, alignment: .leading)
                .padding(.top, 2)

            Divider()
                .padding(.top, 8)

            Group {
                if let committed = operationalState.committedETASeconds {
                    Text("Revised ETA \(AviationMapSymbology.formatDuration(committed))")
                        .fontWeight(.semibold)
                        .monospacedDigit()
                } else {
                    Text("No revision committed")
                }
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
            .frame(height: 20, alignment: .leading)
            .padding(.top, 13)

            HStack(spacing: 10) {
                calloutActionButton(
                    operationalState.committedETASeconds == nil ? "Revise ETA" : "Edit ETA",
                    color: Color(uiColor: visualStyle.primaryActionColor)
                ) {
                    let targetKey = NavigationTimingTargetKey(
                        legID: point.id.legID,
                        kind: .identificationPoint,
                        targetID: point.id.identificationPointID
                    )
                    if operationalState.committedETASeconds != nil { onEdit(targetKey) }
                    onRevise(targetKey)
                }
                .accessibilityIdentifier("edit-identification-point-eta")

                calloutActionButton(
                    "Reached",
                    color: Color(uiColor: visualStyle.cockpitProgressionActionBackgroundColor),
                    action: onReach
                )
                .accessibilityIdentifier("identification-point-reached")
            }
            .padding(.top, 14)

            Text("Reached is available only inside this callout.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(height: 20, alignment: .leading)
                .padding(.top, 10)
        }
        .padding(.horizontal, 17)
        .padding(.top, 15)
        .padding(.bottom, 15)
        .overlay(alignment: .trailing) {
            Button(action: onCollapseOrExpand) {
                Image(systemName: "line.3.horizontal")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 32, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Collapse identification point callout")
        }
    }

    private func reachedResultCallout(
        context: AviationMapIdentificationContext,
        actual: Int
    ) -> some View {
        let expected = point.committedETASeconds ?? point.plannedElapsedSeconds
        return VStack(alignment: .leading, spacing: 0) {
            Text(kicker(for: point.operationalState))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color(uiColor: visualStyle.primaryActionColor))
                .frame(height: 20, alignment: .leading)
            Text("Actual ETA \(AviationMapSymbology.formatDuration(actual))")
                .font(.body.weight(.semibold).monospacedDigit())
                .frame(height: 20, alignment: .leading)
                .padding(.top, 2)
            Divider().padding(.top, 8)
            HStack(alignment: .top, spacing: 10) {
                timingColumn(
                    point.committedETASeconds == nil ? "EXPECTED · PLANNED" : "EXPECTED · REVISED",
                    expected,
                    color: .primary
                )
                timingColumn(
                    "ACTUAL",
                    actual,
                    color: .primary,
                    titleColor: Color(uiColor: visualStyle.identificationPointReachedColor)
                )
            }
            .padding(.top, 13)
            Text(timingDifferenceDescription(actual - expected))
                .font(.title3.weight(.bold))
                .foregroundStyle(.orange)
                .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
                .padding(.horizontal, 13)
                .background(Color.orange.opacity(0.10), in: RoundedRectangle(cornerRadius: 12))
                .overlay { RoundedRectangle(cornerRadius: 12).stroke(Color(uiColor: .systemGray4)) }
                .padding(.top, 17)

            if let target = context.nextTarget {
                calloutActionButton(
                    "Revise Next ETA",
                    color: Color(uiColor: visualStyle.primaryActionColor)
                ) {
                    if target.committedETASeconds != nil { onEdit(target.id) }
                    onRevise(target.id)
                }
                .frame(height: 46)
                .padding(.top, 18)
            }
            Text("Pilot-reported position fix · not GPS verified")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(height: 20, alignment: .leading)
                .padding(.top, 8)
        }
        .padding(.horizontal, 17)
        .padding(.top, 15)
        .padding(.bottom, 5)
    }

    private func calloutActionButton(
        _ title: LocalizedStringKey,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(color, in: RoundedRectangle(cornerRadius: 12))
    }

    private var collapsed: some View {
        Text(point.status == .passedWithoutReport
            ? "\(point.name) · Passed without report"
            : point.name)
            .font(.caption.weight(.bold))
            .foregroundStyle(point.status == .passedWithoutReport ? .secondary : .primary)
            .shadow(color: .white, radius: 2)
            .accessibilityLabel(point.status == .passedWithoutReport
                ? "\(point.name), passed without report, no Actual ETA"
                : point.name)
    }

    private func expanded(_ context: AviationMapIdentificationContext) -> some View {
        let operationalState = point.operationalState
        return VStack(alignment: .leading, spacing: 9) {
            Button(action: onCollapseOrExpand) {
                HStack {
                    Text(kicker(for: operationalState)).font(.caption.weight(.bold)).tracking(0.7)
                    Spacer()
                    Image(systemName: "chevron.up")
                }
                .foregroundStyle(Color(uiColor: calloutAccentColor))
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if let reportError = context.reportError {
                if let actual = context.actualElapsedSeconds {
                    Text("Actual ETA \(AviationMapSymbology.formatDuration(actual))")
                        .font(.title3.weight(.bold).monospacedDigit())
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("Reach report not recorded")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.red)
                    Text(reportError.localizedDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
                Text("Existing timing and reach history remain unchanged.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else if operationalState.isPassedWithoutReport {
                Text("Passed without report")
                    .font(.title3.weight(.bold))
                Divider()
                Text("Passed without report")
                    .font(.subheadline.weight(.semibold))
                Text("No reach timestamp or Actual ETA was recorded.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if operationalState.canMarkReached {
                futureContent(operationalState)
            } else if operationalState.isReached, let actual = context.actualElapsedSeconds {
                reachedContent(context: context, actual: actual)
            }
        }
    }

    @ViewBuilder
    private func futureContent(_ operationalState: AviationMapIdentificationPointOperationalState) -> some View {
        Text("Planned ETA \(AviationMapSymbology.formatDuration(operationalState.plannedElapsedSeconds))")
            .font(.title3.weight(.bold).monospacedDigit())
        Divider()
        if let committed = operationalState.committedETASeconds {
            Text("Revised ETA \(AviationMapSymbology.formatDuration(committed))")
                .font(.subheadline.weight(.semibold).monospacedDigit())
        } else {
            Text("No revision committed")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        HStack(spacing: 8) {
            Button(operationalState.committedETASeconds == nil ? "Revise ETA" : "Edit ETA") {
                let targetKey = NavigationTimingTargetKey(
                    legID: point.id.legID,
                    kind: .identificationPoint,
                    targetID: point.id.identificationPointID
                )
                if operationalState.committedETASeconds != nil { onEdit(targetKey) }
                onRevise(targetKey)
            }
            .tint(Color(uiColor: visualStyle.primaryActionColor))
            .accessibilityIdentifier("edit-identification-point-eta")

            Button("Reached", action: onReach)
                .tint(Color(uiColor: visualStyle.cockpitProgressionActionBackgroundColor))
                .accessibilityIdentifier("identification-point-reached")
        }
        .font(.subheadline.weight(.semibold))
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        Text("Reached is available only inside this callout.")
            .font(.caption2)
            .foregroundStyle(.secondary)
    }

    @ViewBuilder
    private func reachedContent(context: AviationMapIdentificationContext, actual: Int) -> some View {
        let expected = point.committedETASeconds ?? point.plannedElapsedSeconds
        Text("Actual ETA \(AviationMapSymbology.formatDuration(actual))")
            .font(.title3.weight(.bold).monospacedDigit())
        Divider()
        HStack(alignment: .top, spacing: 12) {
            timingColumn(
                point.committedETASeconds == nil ? "EXPECTED · PLANNED" : "EXPECTED · REVISED",
                expected,
                color: .secondary
            )
            timingColumn(
                "ACTUAL",
                actual,
                color: Color(uiColor: visualStyle.identificationPointReachedColor)
            )
        }
        Text(timingDifferenceDescription(actual - expected))
            .font(.caption.weight(.semibold))
            .foregroundStyle(.orange)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(Color.orange.opacity(0.12), in: Capsule())

        if let target = context.nextTarget {
                Divider()
            Button("Revise Next ETA") {
                if target.committedETASeconds != nil { onEdit(target.id) }
                onRevise(target.id)
            }
            .font(.subheadline.weight(.semibold))
            .frame(maxWidth: .infinity, minHeight: 44)
            .buttonStyle(.borderedProminent)
            .tint(Color(uiColor: visualStyle.primaryActionColor))
        }
        Text("Pilot-reported position fix · not GPS verified")
            .font(.caption2)
            .foregroundStyle(.secondary)
    }

    private var calloutAccentColor: UIColor {
        switch point.status {
        case .future: visualStyle.identificationPointColor
        case .reached: visualStyle.identificationPointReachedColor
        case .passedWithoutReport: visualStyle.identificationPointPassedColor
        }
    }

    private func kicker(
        for operationalState: AviationMapIdentificationPointOperationalState
    ) -> String {
        switch operationalState.status {
        case .future: "\(point.name.uppercased()) · FUTURE TARGET"
        case .reached: "\(point.name.uppercased()) · REACHED"
        case .passedWithoutReport: "\(point.name.uppercased()) · HISTORICAL"
        }
    }

    private func timingColumn(
        _ title: String,
        _ seconds: Int,
        color: Color,
        titleColor: Color = .secondary
    ) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption2.weight(.bold))
                .foregroundStyle(titleColor)
            Text(AviationMapSymbology.formatDuration(seconds))
                .monospacedDigit()
                .font(.headline.weight(.bold))
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func timingDifferenceDescription(_ seconds: Int) -> String {
        if seconds == 0 { return "On time" }
        return "\(abs(seconds)) seconds \(seconds > 0 ? "late" : "early")"
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
