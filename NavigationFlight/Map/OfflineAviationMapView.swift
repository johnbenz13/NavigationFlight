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
    @Binding var preservedCamera: AviationMapCameraState?
    @Binding var isCameraUserControlled: Bool

    init(
        presentation: AviationMapPresentation,
        legState: FlightSession.LegState,
        focusRequest: AviationMapFocusRequest,
        resources: any AviationMapResourceProviding = BundledAviationMapResourceProvider(),
        preservedCamera: Binding<AviationMapCameraState?>,
        isCameraUserControlled: Binding<Bool>
    ) {
        self.presentation = presentation
        self.legState = legState
        self.focusRequest = focusRequest
        self.resources = resources
        _preservedCamera = preservedCamera
        _isCameraUserControlled = isCameraUserControlled
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            presentation: presentation,
            legState: legState,
            focusRequest: focusRequest,
            chartURL: resources.chartURL(),
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
        }

        private var presentation: AviationMapPresentation
        private var legState: FlightSession.LegState
        private var lastFocusRequest: AviationMapFocusRequest
        private let chartURL: URL?
        private let initialCamera: AviationMapCameraState?
        private let preservedCamera: Binding<AviationMapCameraState?>
        private let isCameraUserControlled: Binding<Bool>
        private var styleIsReady = false
        private var endpointAnnotations: [MLNPointAnnotation] = []

        init(
            presentation: AviationMapPresentation,
            legState: FlightSession.LegState,
            focusRequest: AviationMapFocusRequest,
            chartURL: URL?,
            initialCamera: AviationMapCameraState?,
            preservedCamera: Binding<AviationMapCameraState?>,
            isCameraUserControlled: Binding<Bool>
        ) {
            self.presentation = presentation
            self.legState = legState
            self.lastFocusRequest = focusRequest
            self.chartURL = chartURL
            self.initialCamera = initialCamera
            self.preservedCamera = preservedCamera
            self.isCameraUserControlled = isCameraUserControlled
        }

        func mapView(_ mapView: MLNMapView, didFinishLoading style: MLNStyle) {
            addChart(to: style)
            addRoute(to: style)
            addWaypoints(to: style)
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
        }

        func mapView(_ mapView: MLNMapView, viewFor annotation: MLNAnnotation) -> MLNAnnotationView? {
            guard let annotation = annotation as? EndpointAnnotation else { return nil }
            let identifier = "endpoint-\(annotation.identifier.uuidString)"
            return EndpointAnnotationView(annotation: annotation, reuseIdentifier: identifier)
        }

        func update(
            presentation: AviationMapPresentation,
            legState: FlightSession.LegState,
            focusRequest: AviationMapFocusRequest,
            mapView: MLNMapView
        ) {
            let becameActive = self.legState == .ready && legState == .active
            let presentationChanged = self.presentation != presentation
            self.presentation = presentation
            self.legState = legState

            guard styleIsReady else {
                lastFocusRequest = focusRequest
                return
            }

            if presentationChanged, let style = mapView.style {
                updateShapes(in: style)
                updateEndpointAnnotations(on: mapView)
            }

            if becameActive {
                focusLeg(on: mapView, animated: true)
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
            active.lineColor = NSExpression(forConstantValue: UIColor.systemCyan)
            active.lineWidth = NSExpression(forConstantValue: 6)
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
            preview.lineColor = NSExpression(forConstantValue: UIColor.systemOrange)
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

        private func updateShapes(in style: MLNStyle) {
            (style.source(withIdentifier: Identifier.routeSource) as? MLNShapeSource)?.shape = routeShape()
            (style.source(withIdentifier: Identifier.previewSource) as? MLNShapeSource)?.shape = previewShape()
            (style.source(withIdentifier: Identifier.waypointSource) as? MLNShapeSource)?.shape = waypointShape()
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

        private func focusLeg(on mapView: MLNMapView, animated: Bool) {
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
                    animated: animated
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
            animated: Bool
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
            mapView.setCamera(camera, animated: animated)
        }

        private func updateEndpointAnnotations(on mapView: MLNMapView) {
            if !endpointAnnotations.isEmpty {
                mapView.removeAnnotations(endpointAnnotations)
            }
            endpointAnnotations = presentation.waypoints.compactMap { waypoint in
                guard waypoint.role != .route else { return nil }
                let reference = presentation.endpointReferences.first { $0.waypointID == waypoint.id }
                return EndpointAnnotation(waypoint: waypoint, reference: reference)
            }
            mapView.addAnnotations(endpointAnnotations)
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
    let titleText: String
    let referenceText: String?

    init(waypoint: AviationMapWaypoint, reference: AviationMapVORDMEReference?) {
        identifier = waypoint.id
        role = waypoint.role
        titleText = "\(waypoint.role == .from ? "FROM" : "TO") · \(waypoint.name)"
        if let reference {
            let radial = Int(reference.magneticRadialFromDegrees.rounded())
            referenceText = "\(reference.stationIdentifier) · \(reference.frequencyMHz.formatted(.number.precision(.fractionLength(2...3)))) · \(radial)° FROM · \(reference.slantRangeNauticalMiles.formatted(.number.precision(.fractionLength(1)))) NM"
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
    init(annotation: EndpointAnnotation, reuseIdentifier: String) {
        super.init(reuseIdentifier: reuseIdentifier)

        let label = UILabel()
        label.numberOfLines = annotation.referenceText == nil ? 1 : 2
        label.textAlignment = .center
        label.font = .preferredFont(forTextStyle: .caption2)
        label.textColor = .label
        label.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.92)
        label.layer.cornerRadius = 7
        label.layer.borderColor = UIColor.systemBlue.cgColor
        label.layer.borderWidth = annotation.role == .to ? 2.5 : 1.5
        label.layer.masksToBounds = true
        label.text = [annotation.titleText, annotation.referenceText].compactMap { $0 }.joined(separator: "\n")
        let measured = label.sizeThatFits(CGSize(width: 220, height: 80))
        let size = CGSize(width: measured.width + 14, height: measured.height + 8)
        frame = CGRect(origin: .zero, size: size)
        label.frame = bounds
        addSubview(label)
        centerOffset = CGVector(dx: 0, dy: -(size.height / 2 + 8))
        isEnabled = false
    }

    required init?(coder: NSCoder) {
        return nil
    }
}
