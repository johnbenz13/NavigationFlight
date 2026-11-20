import MapLibre
import SwiftUI

struct FlightDebriefLoaderView: View {
    @State private var model: FlightDebriefModel

    init(id: UUID, library: FlightRecordingLibrary) {
        _model = State(initialValue: FlightDebriefModel {
            try await library.debriefEvidence(id: id)
        })
    }

    var body: some View {
        Group {
            switch model.state {
            case .loading:
                ProgressView("Preparing Debrief")
            case .failed:
                ContentUnavailableView("Debrief unavailable", systemImage: "exclamationmark.triangle", description: Text("The retained evidence could not be projected."))
            case .loaded(let debrief):
                FlightDebriefView(model: model, debrief: debrief)
            }
        }
        .task { await model.load() }
        .onDisappear { model.pause() }
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("flight-debrief")
    }
}

struct FlightDebriefView: View {
    let model: FlightDebriefModel
    let debrief: FlightDebrief

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                FlightDebriefIdentityView(debrief: debrief)
                FlightDebriefMapSection(
                    model: model,
                    debrief: debrief,
                    height: model.consoleMode == .compact ? 600 : 472
                )
                if model.consoleMode == .compact {
                    FlightDebriefCompactTelemetrySection(model: model)
                } else {
                    FlightDebriefTelemetrySection(model: model, debrief: debrief)
                }
                FlightDebriefTimelineSection(
                    model: model,
                    debrief: debrief,
                    isCompact: model.consoleMode == .compact
                )
            }
        }
        .background(Color(.systemBackground))
    }
}

private struct FlightDebriefIdentityView: View {
    let debrief: FlightDebrief

    var body: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 2) {
                Text(debrief.routeName).font(.largeTitle)
                Text("\(debrief.startedAt, format: .dateTime.day().month().year()) · \(debrief.duration.formatted(.time(pattern: .hourMinuteSecond))) · GPS coverage \(coverageText)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("Complete · Historical")
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(.secondarySystemBackground), in: .capsule)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }

    private var coverageText: String {
        guard let fraction = debrief.gpsCoverageFraction else { return "unavailable" }
        return fraction.formatted(.percent.precision(.fractionLength(0)))
    }
}

private struct FlightDebriefMapSection: View {
    @Environment(\.accessibilityReduceMotion) private var reducesMotion
    let model: FlightDebriefModel
    let debrief: FlightDebrief
    let height: CGFloat

    var body: some View {
        ZStack {
            if true {
                HistoricalFlightMapView(
                debrief: debrief,
                selectedSample: model.selection?.sample,
                selectedEventID: model.selection?.event?.id,
                selectedElapsed: model.selection?.elapsed ?? .zero,
                orientation: model.mapOrientation,
                cameraMode: model.cameraMode,
                cameraRequest: model.cameraRequest,
                fitsFullFlight: model.fitsFullFlight,
                showsDriftLines: model.areDriftLinesVisible,
                reducesMotion: reducesMotion,
                onMapInteraction: model.enterFreeLook,
                onSelectEvent: model.select
                )
                .frame(height: height)
            } else {
                Color(.secondarySystemBackground).frame(height: height)
            }
            if model.selection?.sample == nil {
                ContentUnavailableView(
                    "No recorded position",
                    systemImage: "location.slash",
                    description: Text("Flight evidence remains available below, but the recording has no trustworthy GPS position to place on the chart.")
                )
                .padding(32)
                .background(.regularMaterial, in: .rect(cornerRadius: 18))
            } else {
                VStack {
                    HStack(alignment: .top) {
                        FlightDebriefMapLegend()
                        Spacer()
                        FlightDebriefMapControls(model: model)
                    }
                    Spacer()
                    HStack(alignment: .bottom) {
                        FlightDebriefSelectionCard(selection: model.selection)
                        Spacer()
                    }
                }
                .padding(16)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(mapAccessibilityLabel)
        .accessibilityIdentifier("flight-debrief.map-section")
    }

    private func positionDisclosure(_ position: FlightDebriefEvent.Position) -> String {
        switch position {
        case .direct(_, let accuracy): "Direct recorded position · ±\(accuracy.formatted(.number.precision(.fractionLength(0)))) m"
        case .correlated(_, let delta, let accuracy): "Correlated GPS sample \(delta.timeOffsetText) · ±\(accuracy.formatted(.number.precision(.fractionLength(0)))) m"
        case .unavailable: "No trustworthy position is available"
        }
    }

    private var mapAccessibilityLabel: String {
        "Historical map in \(model.mapOrientation == .northUp ? "North-up" : "Track-up"), \(model.cameraMode == .followAircraft ? "following aircraft" : "Free Look"). Planned leg and \(debrief.trackSegments.count) recorded track segments are shown. Track gaps are not connected."
    }

}

private struct FlightDebriefMapLegend: View {
    var body: some View {
        HStack(spacing: 12) {
            legend("Leg", color: Color(uiColor: AviationMapVisualStyle.default.activeLegColor), dashed: false)
            legend("Track", color: .cyan, dashed: false)
            Label("Action", systemImage: "circle.fill").foregroundStyle(.orange)
        }
        .font(.caption.weight(.semibold))
        .padding(.horizontal, 12)
        .frame(minHeight: 44)
        .background(.regularMaterial, in: .capsule)
    }

    private func legend(_ title: LocalizedStringKey, color: Color, dashed: Bool) -> some View {
        HStack(spacing: 5) {
            Capsule().fill(color).frame(width: 22, height: dashed ? 2 : 4)
            Text(title)
        }
    }
}

private struct FlightDebriefMapControls: View {
    let model: FlightDebriefModel

    var body: some View {
        VStack(spacing: 0) {
            control(model.mapOrientation == .northUp ? "location.north.line.fill" : "location.north.fill", label: model.mapOrientation == .northUp ? "Switch to Track-up" : "Switch to North-up", value: model.mapOrientation == .northUp ? "North-up" : "Track-up", identifier: "flight-debrief.orientation", selected: model.mapOrientation == .trackUp, action: model.toggleOrientation)
            Divider().padding(.horizontal, 8)
            control("scope", label: "Recenter aircraft", value: model.cameraMode == .followAircraft ? "Following aircraft" : "Available", identifier: "flight-debrief.recenter", selected: model.cameraMode == .followAircraft, action: model.recenter)
            Divider().padding(.horizontal, 8)
            control("hand.draw.fill", label: "Free Look", value: model.cameraMode == .freeLook ? "On" : "Off", identifier: "flight-debrief.free-look", selected: model.cameraMode == .freeLook, action: model.enterFreeLook)
            Divider().padding(.horizontal, 8)
            control("wind", label: "Drift lines", value: model.areDriftLinesVisible ? "On" : "Off", identifier: "flight-debrief.drift-lines", selected: model.areDriftLinesVisible, action: model.toggleDriftLines)
        }
        .frame(width: 52)
        .background(.regularMaterial, in: .rect(cornerRadius: 14))
        .overlay { RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.55), lineWidth: 0.5) }
    }

    private func control(_ symbol: String, label: LocalizedStringKey, value: LocalizedStringKey, identifier: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.body.weight(.semibold)).frame(width: 50, height: 48).contentShape(.rect)
        }
        .buttonStyle(.plain)
        .foregroundStyle(selected ? Color.white : Color.primary)
        .background(selected ? Color.accentColor : .clear)
        .accessibilityLabel(label)
        .accessibilityValue(value)
        .accessibilityIdentifier(identifier)
    }
}

private struct FlightDebriefSelectionCard: View {
    let selection: FlightDebriefSelection?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(selection?.event?.title ?? "Historical position").font(.body.weight(.semibold))
            if let event = selection?.event {
                Text("\(event.elapsed.formatted(.time(pattern: .hourMinuteSecond))) · \(event.origin.rawValue) action")
                    .font(.caption).foregroundStyle(.secondary)
                Text(positionDisclosure(event.position)).font(.caption).foregroundStyle(.orange)
            }
        }
        .padding(12)
        .background(.regularMaterial, in: .rect(cornerRadius: 14))
        .accessibilityIdentifier("flight-debrief.selection")
    }

    private func positionDisclosure(_ position: FlightDebriefEvent.Position) -> String {
        switch position {
        case .direct(_, let accuracy): "Direct recorded position · ±\(accuracy.formatted(.number.precision(.fractionLength(0)))) m"
        case .correlated(_, let delta, let accuracy): "Correlated GPS sample \(delta.timeOffsetText) · ±\(accuracy.formatted(.number.precision(.fractionLength(0)))) m"
        case .unavailable: "No trustworthy position is available"
        }
    }
}

private struct FlightDebriefTelemetrySection: View {
    let model: FlightDebriefModel
    let debrief: FlightDebrief

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Flight parameters").font(.title3)
                Spacer()
                Text(model.selection?.elapsed.formatted(.time(pattern: .hourMinuteSecond)) ?? "00:00:00")
                    .font(.caption)
                    .foregroundStyle(.tint)
                Text(courseText)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.tint)
                FlightDebriefConsoleModeButton(model: model)
            }
            FlightDebriefPlot(title: "Altitude", value: altitudeText, rangeLabel: altitudeRange, observations: debrief.altitudeObservations, selectedTime: model.selection?.elapsed ?? .zero)
            FlightDebriefPlot(title: "Ground speed", value: speedText, rangeLabel: speedRange, observations: debrief.groundSpeedObservations, selectedTime: model.selection?.elapsed ?? .zero)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
    }

    private var altitudeRange: String { range(debrief.altitudeObservations.map { $0.value * 3.28084 }, unit: "ft") }
    private var speedRange: String { range(debrief.groundSpeedObservations.map { $0.value * 1.94384 }, unit: "kt") }
    private var altitudeText: String { model.selection?.sample?.altitudeMeters.map { "\(($0 * 3.28084).formatted(.number.precision(.fractionLength(0)))) ft" } ?? "Unavailable" }
    private var speedText: String { model.selection?.sample?.groundSpeedMetersPerSecond.map { "\(($0 * 1.94384).formatted(.number.precision(.fractionLength(0)))) kt" } ?? "Unavailable" }
    private var courseText: String { model.selection?.sample?.courseDegrees.map { "Course \($0.formatted(.number.precision(.fractionLength(0))))°" } ?? "Course unavailable" }
    private func range(_ values: [Double], unit: String) -> String {
        guard let maximum = values.max() else { return "Unavailable" }
        return "0–\(maximum.formatted(.number.precision(.fractionLength(0)))) \(unit)"
    }
}

private struct FlightDebriefPlot: View {
    let title: LocalizedStringKey
    let value: String
    let rangeLabel: String
    let observations: [FlightDebriefObservation]
    let selectedTime: Duration

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading) {
                Text(title).font(.body)
                Text(value).font(.caption).foregroundStyle(.tint)
                Spacer()
                Text(rangeLabel).font(.caption).foregroundStyle(.secondary)
            }
            .frame(width: 116, alignment: .leading)
            Canvas { context, size in
                guard observations.count > 1, let maximum = observations.map(\.value).max(), maximum > 0,
                      let total = observations.last?.elapsed.timeInterval, total > 0 else { return }
                var path = Path()
                for (index, observation) in observations.enumerated() {
                    let point = CGPoint(x: size.width * observation.elapsed.timeInterval / total, y: size.height * (1 - observation.value / maximum))
                    index == 0 ? path.move(to: point) : path.addLine(to: point)
                }
                context.stroke(path, with: .color(.teal), lineWidth: 2)
                let selectedX = size.width * min(selectedTime.timeInterval / total, 1)
                context.stroke(Path(CGRect(x: selectedX, y: 0, width: 1, height: size.height)), with: .color(.orange), lineWidth: 1)
            }
            .frame(height: 94)
            .background(Color(.secondarySystemBackground).opacity(0.35))
        }
    }
}

private struct FlightDebriefCompactTelemetrySection: View {
    let model: FlightDebriefModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 4) {
                Text("Replay console").font(.title3.weight(.semibold))
                Text(model.selection?.elapsed.formatted(.time(pattern: .hourMinuteSecond)) ?? "00:00:00")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.tint)
                Spacer()
                FlightDebriefConsoleModeButton(model: model)
            }
            HStack(spacing: 8) {
                instrument("Altitude", value: altitudeValue, unit: "ft", symbol: "arrow.up.and.down")
                instrument("Ground speed", value: speedValue, unit: "kt", symbol: "gauge.with.dots.needle.67percent")
                instrument("Course", value: courseValue, unit: "°", symbol: "location.north.line")
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .padding(.bottom, 14)
        .background(Color(.secondarySystemBackground))
        .accessibilityIdentifier("flight-debrief.compact-console")
    }

    private func instrument(_ title: LocalizedStringKey, value: String, unit: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title).font(.caption).foregroundStyle(.secondary)
                Spacer()
                Image(systemName: symbol).foregroundStyle(.secondary)
            }
            HStack(alignment: .firstTextBaseline) {
                Text(value).font(.title2.weight(.semibold)).monospacedDigit()
                Spacer(minLength: 4)
                Text(unit).font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
        .background(Color(.systemBackground), in: .rect(cornerRadius: 12))
    }

    private var altitudeValue: String { model.selection?.sample?.altitudeMeters.map { ($0 * 3.28084).formatted(.number.precision(.fractionLength(0))) } ?? "—" }
    private var speedValue: String { model.selection?.sample?.groundSpeedMetersPerSecond.map { ($0 * 1.94384).formatted(.number.precision(.fractionLength(0))) } ?? "—" }
    private var courseValue: String { model.selection?.sample?.courseDegrees?.formatted(.number.precision(.fractionLength(0))) ?? "—" }
}

private struct FlightDebriefConsoleModeButton: View {
    let model: FlightDebriefModel

    var body: some View {
        Button(model.consoleMode == .compact ? "Show analysis" : "Hide analysis", systemImage: model.consoleMode == .compact ? "chevron.up" : "chevron.down") {
            model.toggleConsoleMode()
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.capsule)
        .controlSize(.small)
        .accessibilityValue(model.consoleMode == .compact ? "Compact replay console" : "Full analysis")
        .accessibilityIdentifier("flight-debrief.analysis-mode")
    }
}

private struct FlightTelemetryValues: View {
    let sample: RecordedTrackSample

    var body: some View {
        ViewThatFits {
            HStack { values }
            VStack(alignment: .leading) { values }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    @ViewBuilder private var values: some View {
        Text("Position \(sample.coordinate.latitudeDegrees.formatted(.number.precision(.fractionLength(4)))), \(sample.coordinate.longitudeDegrees.formatted(.number.precision(.fractionLength(4)))) · ±\(sample.horizontalAccuracyMeters.formatted(.number.precision(.fractionLength(0)))) m")
        if let course = sample.courseDegrees { Text("Course \(course.formatted(.number.precision(.fractionLength(0))))°") }
        if let heading = sample.deviceHeadingDegrees { Text("Heading \(heading.formatted(.number.precision(.fractionLength(0))))°") }
    }
}

private struct FlightDebriefTimelineSection: View {
    let model: FlightDebriefModel
    let debrief: FlightDebrief
    let isCompact: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if isCompact {
                playbackControls
                timelineHeader
            } else {
                timelineHeader
                playbackControls
            }
            ScrollView(.horizontal) {
                LazyHStack(spacing: 10) {
                    ForEach(debrief.events) { event in
                        Button { model.select(eventID: event.id) } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Circle().fill(event.id == model.selection?.event?.id ? Color.orange : Color.teal).frame(width: 8, height: 8)
                                Text(event.title).font(.caption).lineLimit(3)
                                Text(event.elapsed.formatted(.time(pattern: .minuteSecond))).font(.caption2).foregroundStyle(.secondary)
                                if !isCompact {
                                    Text(event.origin.rawValue.capitalized).font(.caption2).foregroundStyle(.tertiary)
                                }
                            }
                            .frame(width: isCompact ? 124 : 112, height: isCompact ? 62 : 118, alignment: .topLeading)
                            .padding(10)
                            .background(Color(.systemBackground), in: .rect(cornerRadius: 12))
                            .overlay { RoundedRectangle(cornerRadius: 12).stroke(Color(.separator), lineWidth: 0.5) }
                        }
                        .buttonStyle(.plain)
                        .accessibilityValue(event.id == model.selection?.event?.id ? "Selected" : "Not selected")
                        .accessibilityIdentifier("flight-debrief.event.\(event.id.uuidString)")
                    }
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
        .background(Color(.secondarySystemBackground))
    }

    private var timelineHeader: some View {
        HStack {
            Text("Actions & phases").font(.title3)
            Spacer()
            Text("\(Int((model.selection?.elapsed ?? .zero).timeInterval / 60)) of \(Int(debrief.duration.timeInterval / 60)) minutes")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private var playbackControls: some View {
        HStack(spacing: 16) {
            Button(model.isPlaying ? "Pause" : "Play", systemImage: model.isPlaying ? "pause.fill" : "play.fill") {
                model.isPlaying ? model.pause() : model.play()
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("flight-debrief.play-pause")
            VStack {
                HStack {
                    Text((model.selection?.elapsed ?? .zero).formatted(.time(pattern: .hourMinuteSecond)))
                    Spacer()
                    Text(debrief.duration.formatted(.time(pattern: .hourMinuteSecond)))
                }.font(.caption)
                Slider(value: selectedSeconds, in: 0...max(debrief.duration.timeInterval, 1))
                    .accessibilityIdentifier("flight-debrief.timeline")
            }
            Picker("Playback speed", selection: Binding(get: { model.playbackRate }, set: { model.playbackRate = $0 })) {
                ForEach(FlightDebriefModel.PlaybackRate.allCases) { rate in Text("×\(rate.rawValue)").tag(rate) }
            }
            .pickerStyle(.menu)
            .accessibilityIdentifier("flight-debrief.rate")
            Button("Fit full flight", systemImage: "arrow.up.left.and.arrow.down.right") {
                model.showFullFlight()
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("flight-debrief.fit-full-flight")
        }
    }

    private var selectedSeconds: Binding<Double> {
        Binding(get: { model.selection?.elapsed.timeInterval ?? 0 }, set: { model.seek(to: .seconds($0)) })
    }
}

private struct HistoricalFlightMapView: UIViewRepresentable {
    let debrief: FlightDebrief
    let selectedSample: RecordedTrackSample?
    let selectedEventID: UUID?
    let selectedElapsed: Duration
    let orientation: FlightDebriefModel.MapOrientation
    let cameraMode: FlightDebriefModel.CameraMode
    let cameraRequest: Int
    let fitsFullFlight: Bool
    let showsDriftLines: Bool
    let reducesMotion: Bool
    let onMapInteraction: () -> Void
    let onSelectEvent: (UUID) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            debrief: debrief,
            onMapInteraction: onMapInteraction,
            onSelectEvent: onSelectEvent
        )
    }

    func makeUIView(context: Context) -> MLNMapView {
        let resources = BundledAviationMapResourceProvider()
        let view = MLNMapView(frame: .zero, styleURL: resources.styleURL())
        view.delegate = context.coordinator
        view.logoView.isHidden = true
        view.attributionButton.isHidden = true
        view.isRotateEnabled = false
        view.isAccessibilityElement = false
        let actionTap = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.selectAction(_:))
        )
        actionTap.cancelsTouchesInView = false
        view.addGestureRecognizer(actionTap)
        return view
    }

    func updateUIView(_ view: MLNMapView, context: Context) {
        context.coordinator.onMapInteraction = onMapInteraction
        context.coordinator.onSelectEvent = onSelectEvent
        context.coordinator.selectedEventID = selectedEventID
        context.coordinator.update(
            selectedSample: selectedSample,
            selectedElapsed: selectedElapsed,
            orientation: orientation,
            cameraMode: cameraMode,
            cameraRequest: cameraRequest,
            fitsFullFlight: fitsFullFlight,
            showsDriftLines: showsDriftLines,
            reducesMotion: reducesMotion,
            on: view
        )
    }

    final class Coordinator: NSObject, MLNMapViewDelegate {
        let debrief: FlightDebrief
        var onMapInteraction: () -> Void
        var onSelectEvent: (UUID) -> Void
        var selectedEventID: UUID?
        private var aircraftAnnotation: HistoricalAircraftAnnotation?
        private var lastCameraRequest = -1
        private var hasAppliedInitialCamera = false
        private var pendingUpdate: (() -> Void)?
        private var contentInstalled = false

        init(
            debrief: FlightDebrief,
            onMapInteraction: @escaping () -> Void,
            onSelectEvent: @escaping (UUID) -> Void
        ) {
            self.debrief = debrief
            self.onMapInteraction = onMapInteraction
            self.onSelectEvent = onSelectEvent
        }

        @objc func selectAction(_ gesture: UITapGestureRecognizer) {
            guard gesture.state == .ended,
                  let mapView = gesture.view as? MLNMapView else { return }
            let features = mapView.visibleFeatures(
                at: gesture.location(in: mapView),
                styleLayerIdentifiers: ["debrief-actions"]
            )
            let eventIDs = features.compactMap { feature -> UUID? in
                guard let value = feature.attributes["eventID"] else { return nil }
                return UUID(uuidString: String(describing: value))
            }
            guard !eventIDs.isEmpty else { return }
            let selectedIndex = selectedEventID.flatMap { eventIDs.firstIndex(of: $0) }
            let nextIndex = selectedIndex.map { ($0 + 1) % eventIDs.count } ?? 0
            onSelectEvent(eventIDs[nextIndex])
        }

        func mapView(_ mapView: MLNMapView, didFinishLoading style: MLNStyle) {
            installContentIfNeeded(on: mapView, style: style)
            pendingUpdate?()
        }

        func mapView(_ mapView: MLNMapView, regionWillChangeAnimated animated: Bool) {
            let isGesture = mapView.gestureRecognizers?.contains { $0.state == .began || $0.state == .changed } ?? false
            if isGesture { DispatchQueue.main.async { [onMapInteraction] in onMapInteraction() } }
        }

        func mapView(_ mapView: MLNMapView, viewFor annotation: MLNAnnotation) -> MLNAnnotationView? {
            guard let aircraft = annotation as? HistoricalAircraftAnnotation else { return nil }
            return HistoricalAircraftAnnotationView(annotation: aircraft, reuseIdentifier: "historical-aircraft")
        }

        private func installContentIfNeeded(on mapView: MLNMapView, style: MLNStyle) {
            guard !contentInstalled else { return }
            let resources = BundledAviationMapResourceProvider()
            if let chart = resources.chartURL(), let url = URL(string: "pmtiles://\(chart.absoluteString)") {
                let source = MLNRasterTileSource(identifier: "debrief-chart", configurationURL: url, tileSize: 256)
                style.addSource(source)
                style.addLayer(MLNRasterStyleLayer(identifier: "debrief-chart-layer", source: source))
            }
            addLine(
                renderCoordinates(debrief.plannedRoute, maximumCount: 24),
                id: "debrief-planned-route",
                color: AviationMapVisualStyle.default.activeLegColor,
                width: 7,
                to: style
            )
            addMultiLine(
                debrief.trackSegments.map {
                    renderCoordinates($0.samples.map(\.coordinate), maximumCount: 24)
                },
                id: "debrief-recorded-track",
                color: .systemCyan,
                width: 4,
                to: style
            )
            addDriftLines(to: style)
            addMinuteMarks(to: style)
            addActionDots(to: style)
            contentInstalled = true
        }

        func update(selectedSample: RecordedTrackSample?, selectedElapsed: Duration, orientation: FlightDebriefModel.MapOrientation, cameraMode: FlightDebriefModel.CameraMode, cameraRequest: Int, fitsFullFlight: Bool, showsDriftLines: Bool, reducesMotion: Bool, on mapView: MLNMapView) {
            pendingUpdate = { [weak self, weak mapView] in
                guard let self, let mapView else { return }
                self.applyUpdate(selectedSample: selectedSample, selectedElapsed: selectedElapsed, orientation: orientation, cameraMode: cameraMode, cameraRequest: cameraRequest, fitsFullFlight: fitsFullFlight, showsDriftLines: showsDriftLines, reducesMotion: reducesMotion, on: mapView)
            }
            guard contentInstalled else { return }
            pendingUpdate?()
        }

        private func applyUpdate(selectedSample: RecordedTrackSample?, selectedElapsed: Duration, orientation: FlightDebriefModel.MapOrientation, cameraMode: FlightDebriefModel.CameraMode, cameraRequest: Int, fitsFullFlight: Bool, showsDriftLines: Bool, reducesMotion: Bool, on mapView: MLNMapView) {
            updateProgress(selectedElapsed: selectedElapsed, on: mapView)
            (mapView.style?.layer(withIdentifier: "debrief-drift") as? MLNLineStyleLayer)?.isVisible = showsDriftLines
            guard let sample = selectedSample else {
                if let aircraftAnnotation { mapView.removeAnnotation(aircraftAnnotation) }
                aircraftAnnotation = nil
                return
            }
            let coordinate = CLLocationCoordinate2D(latitude: sample.coordinate.latitudeDegrees, longitude: sample.coordinate.longitudeDegrees)
            if let aircraftAnnotation {
                aircraftAnnotation.coordinate = coordinate
                aircraftAnnotation.course = sample.courseDegrees
            } else {
                let annotation = HistoricalAircraftAnnotation(coordinate: coordinate, course: sample.courseDegrees)
                aircraftAnnotation = annotation
                mapView.addAnnotation(annotation)
            }
            if let view = mapView.view(for: aircraftAnnotation!) as? HistoricalAircraftAnnotationView {
                view.update(course: sample.courseDegrees, mapDirection: mapView.direction)
            }
            guard cameraMode == .followAircraft || cameraRequest != lastCameraRequest else { return }
            lastCameraRequest = cameraRequest
            if fitsFullFlight {
                showFullFlight(on: mapView, animated: !reducesMotion)
                return
            }
            let direction = orientation == .trackUp ? sample.courseDegrees ?? 0 : 0
            mapView.contentInset = orientation == .trackUp ? UIEdgeInsets(top: 0, left: 0, bottom: 150, right: 0) : .zero
            let zoom = hasAppliedInitialCamera ? mapView.zoomLevel : 9.5
            hasAppliedInitialCamera = true
            mapView.setCenter(coordinate, zoomLevel: zoom, direction: direction, animated: !reducesMotion && cameraRequest > 0)
        }

        private func updateProgress(selectedElapsed: Duration, on mapView: MLNMapView) {
            let date = debrief.startedAt.addingTimeInterval(selectedElapsed.timeInterval)
            let progressed = debrief.trackSegments.compactMap { segment -> [WGS84Coordinate]? in
                let values = renderCoordinates(
                    segment.samples.filter { $0.observedAt <= date }.map(\.coordinate),
                    maximumCount: 24
                )
                return values.count > 1 ? values : nil
            }
            guard let source = mapView.style?.source(withIdentifier: "debrief-progressed-track-source") as? MLNShapeSource else {
                guard !progressed.isEmpty, let style = mapView.style else { return }
                addMultiLine(
                    progressed,
                    id: "debrief-progressed-track",
                    color: .systemCyan,
                    width: 5,
                    to: style
                )
                return
            }
            source.shape = progressed.isEmpty ? nil : multiLineShape(progressed)
        }

        private func showFullFlight(on mapView: MLNMapView, animated: Bool) {
            let all = renderCoordinates(debrief.plannedRoute + debrief.trackSegments.flatMap { $0.samples.map(\.coordinate) }, maximumCount: 48)
            guard !all.isEmpty else { return }
            let coordinates = all.map { CLLocationCoordinate2D(latitude: $0.latitudeDegrees, longitude: $0.longitudeDegrees) }
            mapView.contentInset = .zero
            mapView.direction = 0
            mapView.setVisibleCoordinates(coordinates, count: UInt(coordinates.count), edgePadding: UIEdgeInsets(top: 54, left: 54, bottom: 54, right: 86), animated: animated)
        }

        private func addActionDots(to style: MLNStyle) {
            let points = debrief.events.compactMap { event -> MLNPointFeature? in
                let coordinate: WGS84Coordinate
                switch event.position {
                case .direct(let value, _), .correlated(let value, _, _): coordinate = value
                case .unavailable: return nil
                }
                let point = MLNPointFeature()
                point.coordinate = CLLocationCoordinate2D(latitude: coordinate.latitudeDegrees, longitude: coordinate.longitudeDegrees)
                point.attributes["eventID"] = event.id.uuidString
                return point
            }
            let source = MLNShapeSource(identifier: "debrief-actions-source", features: points, options: nil)
            style.addSource(source)
            let layer = MLNCircleStyleLayer(identifier: "debrief-actions", source: source)
            layer.circleColor = NSExpression(forConstantValue: UIColor.systemOrange)
            layer.circleRadius = NSExpression(forConstantValue: 5)
            layer.circleStrokeColor = NSExpression(forConstantValue: UIColor.white)
            layer.circleStrokeWidth = NSExpression(forConstantValue: 1.5)
            style.addLayer(layer)
        }


        private func addDriftLines(to style: MLNStyle) {
            guard let first = debrief.plannedRoute.first, let last = debrief.plannedRoute.last,
                  let angle = debrief.plannedDriftAngleDegrees else { return }
            let arms = AviationMapGeometry.driftReferenceArms(
                from: .init(latitude: first.latitudeDegrees, longitude: first.longitudeDegrees),
                to: .init(latitude: last.latitudeDegrees, longitude: last.longitudeDegrees),
                angleDegrees: angle
            )
            let lines = arms.map { arm -> MLNPolylineFeature in
                var coordinates = [arm.from, arm.to].map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
                return MLNPolylineFeature(coordinates: &coordinates, count: UInt(coordinates.count))
            }
            let source = MLNShapeSource(
                identifier: "debrief-drift-source",
                shape: MLNShapeCollectionFeature(shapes: lines),
                options: nil
            )
            style.addSource(source)
            let layer = MLNLineStyleLayer(identifier: "debrief-drift", source: source)
            layer.lineColor = NSExpression(forConstantValue: AviationMapVisualStyle.default.driftReferenceColor)
            layer.lineOpacity = NSExpression(forConstantValue: AviationMapVisualStyle.default.driftReferenceOpacity)
            layer.lineWidth = NSExpression(forConstantValue: AviationMapVisualStyle.default.driftReferenceWidth)
            layer.lineDashPattern = NSExpression(forConstantValue: [2, 2])
            layer.lineCap = NSExpression(forConstantValue: "round")
            style.addLayer(layer)
        }

        private func addMinuteMarks(to style: MLNStyle) {
            guard let first = debrief.plannedRoute.first, let last = debrief.plannedRoute.last,
                  let duration = debrief.plannedDurationSeconds else { return }
            let from = AviationMapCoordinate(latitude: first.latitudeDegrees, longitude: first.longitudeDegrees)
            let to = AviationMapCoordinate(latitude: last.latitudeDegrees, longitude: last.longitudeDegrees)
            let markers = AviationMapSymbology.minuteMarkers(from: from, to: to, plannedDurationSeconds: duration)
            let shapes = markers.map { marker -> MLNPolylineFeature in
                let fraction = AviationMapVisualStyle.default.minuteTickLengthFraction(for: marker.level)
                let before = AviationMapGeometry.interpolate(from: from, to: to, fraction: max(0, marker.fraction - fraction))
                let after = AviationMapGeometry.interpolate(from: from, to: to, fraction: min(1, marker.fraction + fraction))
                let east = after.longitude - before.longitude
                let north = after.latitude - before.latitude
                let length = max(hypot(east, north), .leastNonzeroMagnitude)
                let halfLength = fraction * 0.22
                var coordinates = [
                    CLLocationCoordinate2D(latitude: marker.coordinate.latitude - east / length * halfLength, longitude: marker.coordinate.longitude + north / length * halfLength),
                    CLLocationCoordinate2D(latitude: marker.coordinate.latitude + east / length * halfLength, longitude: marker.coordinate.longitude - north / length * halfLength),
                ]
                return MLNPolylineFeature(coordinates: &coordinates, count: 2)
            }
            guard !shapes.isEmpty else { return }
            let source = MLNShapeSource(identifier: "debrief-minute-marks-source", shape: MLNShapeCollectionFeature(shapes: shapes))
            style.addSource(source)
            let casing = MLNLineStyleLayer(identifier: "debrief-minute-marks-casing", source: source)
            casing.lineColor = NSExpression(forConstantValue: AviationMapVisualStyle.default.minuteTickCasingColor.withAlphaComponent(AviationMapVisualStyle.default.minuteTickCasingOpacity))
            casing.lineWidth = NSExpression(forConstantValue: AviationMapVisualStyle.default.minuteTickCasingWidth)
            style.addLayer(casing)
            let marks = MLNLineStyleLayer(identifier: "debrief-minute-marks", source: source)
            marks.lineColor = NSExpression(forConstantValue: AviationMapVisualStyle.default.minuteTickColor)
            marks.lineWidth = NSExpression(forConstantValue: AviationMapVisualStyle.default.minuteTickWidth)
            style.addLayer(marks)
        }

        private func addLine(_ values: [WGS84Coordinate], id: String, color: UIColor, width: CGFloat, to style: MLNStyle) {
            guard values.count > 1 else { return }
            let shape = lineShape(values)
            let source = MLNShapeSource(identifier: "\(id)-source", shape: shape, options: nil)
            style.addSource(source)
            let layer = MLNLineStyleLayer(identifier: id, source: source)
            layer.lineColor = NSExpression(forConstantValue: color)
            layer.lineWidth = NSExpression(forConstantValue: width)
            style.addLayer(layer)
        }

        private func addMultiLine(_ values: [[WGS84Coordinate]], id: String, color: UIColor, width: CGFloat, to style: MLNStyle) {
            let usable = values.filter { $0.count > 1 }
            guard !usable.isEmpty else { return }
            let source = MLNShapeSource(identifier: "\(id)-source", shape: multiLineShape(usable), options: nil)
            style.addSource(source)
            let layer = MLNLineStyleLayer(identifier: id, source: source)
            layer.lineColor = NSExpression(forConstantValue: color)
            layer.lineWidth = NSExpression(forConstantValue: width)
            style.addLayer(layer)
        }

        private func lineShape(_ values: [WGS84Coordinate]) -> MLNShape {
            precondition(values.count > 1)
            var coordinates = values.map { CLLocationCoordinate2D(latitude: $0.latitudeDegrees, longitude: $0.longitudeDegrees) }
            return MLNPolyline(coordinates: &coordinates, count: UInt(coordinates.count))
        }

        private func multiLineShape(_ values: [[WGS84Coordinate]]) -> MLNShape {
            let lines = values.map { lineShape($0) as! MLNPolyline }
            return MLNMultiPolyline(polylines: lines)
        }

        private func renderCoordinates(_ values: [WGS84Coordinate], maximumCount: Int = 100) -> [WGS84Coordinate] {
            let valid = values.filter {
                $0.latitudeDegrees.isFinite && (-90...90).contains($0.latitudeDegrees)
                    && $0.longitudeDegrees.isFinite && (-180...180).contains($0.longitudeDegrees)
            }.reduce(into: [WGS84Coordinate]()) { result, coordinate in
                if result.last != coordinate { result.append(coordinate) }
            }
            guard valid.count > maximumCount else { return valid }
            let stride = Double(valid.count - 1) / Double(maximumCount - 1)
            return (0..<maximumCount).map { valid[Int((Double($0) * stride).rounded())] }
        }
    }
}

private final class HistoricalAircraftAnnotation: MLNPointAnnotation {
    var course: Double?

    init(coordinate: CLLocationCoordinate2D, course: Double?) {
        self.course = course
        super.init()
        self.coordinate = coordinate
        title = "Historical aircraft"
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

private final class HistoricalAircraftAnnotationView: MLNAnnotationView {
    private let imageView = UIImageView()

    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
        frame = CGRect(x: 0, y: 0, width: 38, height: 38)
        imageView.frame = bounds
        imageView.contentMode = .center
        imageView.tintColor = .white
        imageView.image = UIImage(systemName: "airplane", withConfiguration: UIImage.SymbolConfiguration(pointSize: 24, weight: .bold))
        backgroundColor = UIColor.black.withAlphaComponent(0.78)
        layer.cornerRadius = 9
        layer.borderWidth = 2
        layer.borderColor = UIColor.white.cgColor
        addSubview(imageView)
    }

    convenience init(annotation: HistoricalAircraftAnnotation, reuseIdentifier: String?) {
        self.init(reuseIdentifier: reuseIdentifier)
        self.annotation = annotation
        update(course: annotation.course, mapDirection: 0)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func update(course: Double?, mapDirection: CLLocationDirection) {
        imageView.transform = course.map { CGAffineTransform(rotationAngle: ($0 - mapDirection - 90) * .pi / 180) } ?? .identity
        accessibilityLabel = course == nil ? "Historical aircraft, direction unavailable" : "Historical aircraft, course \(Int(course!.rounded())) degrees"
    }
}

private extension Duration {
    nonisolated var timeInterval: TimeInterval {
        let components = self.components
        return Double(components.seconds) + Double(components.attoseconds) / 1e18
    }

    var timeOffsetText: String {
        let value = timeInterval
        return String(format: "%+.1f s", value)
    }
}
