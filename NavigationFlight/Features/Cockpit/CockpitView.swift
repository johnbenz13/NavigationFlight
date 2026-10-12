import SwiftUI

#if DEBUG
private extension CockpitPresentationData {
    static func cockpitPreview(heading: Double?, populated: Bool, hebrew: Bool = false) -> CockpitPresentationData {
        CockpitPresentationData(
            planTitle: "Preview training plan",
            legPosition: "Leg 2 of 5",
            origin: hebrew ? "חדרה" : "Long Departure Reporting Point",
            destination: hebrew ? "עירון" : "Long Arrival Reporting Point",
            originNormalizedX: 0.18,
            originNormalizedY: 0.69,
            destinationNormalizedX: 0.79,
            destinationNormalizedY: 0.30,
            originCrossingAltitudeFeet: 1_500,
            destinationCrossingAltitudeFeet: 2_000,
            magneticCourseDegrees: 68,
            magneticHeadingDegrees: heading,
            distanceNauticalMiles: 7.2,
            groundSpeedKnots: 98,
            legDurationSeconds: 263,
            cumulativeDurationSeconds: 742,
            initialAltitudeFeetMsl: 1_800,
            mode: heading == nil ? .noWind : .wind,
            supportsWindMode: true,
            references: populated ? [
                .init(id: UUID(), endpointName: hebrew ? "עירון" : "Long Arrival Reporting Point", station: "HDF", frequencyMHz: 113.5, magneticRadialFromDegrees: 245, slantRangeNauticalMiles: 18.6, source: .automatic)
            ] : [],
            frequencies: populated ? [
                .departure: [.init(id: "preview-frequency", phase: .departure, role: "Pilot override", service: "Very Long Preview Tower Service", frequencyMHz: 118.4, source: .user)]
            ] : [:],
            displayFrequencies: populated ? [
                .init(id: "preview-frequency", phases: [.departure], service: "Very Long Preview Tower Service", serviceType: "Pilot override", frequencyMHz: 118.4, source: .user)
            ] : [],
            routeEvents: populated ? [
                .init(id: UUID(), entityIDs: [UUID()], kinds: [.altitudeChange], normalizedX: 0.40, normalizedY: 0.57, position: .init(latitudeDegrees: 32.2, longitudeDegrees: 34.6), timeFromLegStartSeconds: 132, title: "Altitude change", detail: "After passing anchor: 2,500 ft MSL"),
                .init(id: UUID(), entityIDs: [UUID()], kinds: [.radioFrequencyChange], normalizedX: 0.61, normalizedY: 0.44, position: .init(latitudeDegrees: 32.25, longitudeDegrees: 34.65), timeFromLegStartSeconds: 190, title: "Frequency change", detail: "Very Long Preview Control Service · 120.600 MHz")
            ] : []
        )
    }
}

private extension FlightSession {
    static let preview = FlightSession(
        flightID: UUID(),
        activeLegIndex: 1,
        executionMode: .wind
    )
}

private extension AviationMapPresentation {
    static let preview: AviationMapPresentation = {
        let from = AviationMapCoordinate(latitude: 32.45, longitude: 34.90)
        let to = AviationMapCoordinate(latitude: 32.60, longitude: 35.03)
        let fromID = UUID()
        let toID = UUID()
        return AviationMapPresentation(
            waypoints: [
                .init(id: fromID, name: "Departure", coordinate: from, role: .from),
                .init(id: toID, name: "Destination", coordinate: to, role: .to)
            ],
            legs: [.init(id: UUID(), index: 0, from: from, to: to)],
            activeLegIndex: 0,
            nextLegPreview: nil,
            endpointReferences: []
        )
    }()
}

#Preview("11-inch iPad Portrait · Wind", traits: .fixedLayout(width: 834, height: 1210)) {
    CockpitView(data: .cockpitPreview(heading: 74, populated: true), mapPresentation: .preview, session: .preview, onStartLeg: {}, onShowPlanInspection: {})
}

#Preview("11-inch iPad Portrait · No Wind · Hebrew", traits: .fixedLayout(width: 834, height: 1210)) {
    CockpitView(data: .cockpitPreview(heading: nil, populated: true, hebrew: true), mapPresentation: .preview, session: .preview, onStartLeg: {}, onShowPlanInspection: {})
}

#Preview("11-inch iPad Landscape · Missing Optional Data", traits: .fixedLayout(width: 1210, height: 834)) {
    CockpitView(data: .cockpitPreview(heading: nil, populated: false), mapPresentation: .preview, session: .preview, onStartLeg: {}, onShowPlanInspection: {})
}

#Preview("11-inch iPad Landscape · Dark", traits: .fixedLayout(width: 1210, height: 834)) {
    CockpitView(data: .cockpitPreview(heading: 74, populated: true), mapPresentation: .preview, session: .preview, onStartLeg: {}, onShowPlanInspection: {})
        .preferredColorScheme(.dark)
}
#endif

struct CockpitView: View {
    let data: CockpitPresentationData
    let mapPresentation: AviationMapPresentation
    let session: FlightSession
    let onStartLeg: () -> Void
    let onShowPlanInspection: () -> Void
    @State private var showsChartsUnavailable = false
    @State private var mapFocusRequest = AviationMapFocusRequest(mode: .leg)
    @State private var preservedMapCamera: AviationMapCameraState?
    @State private var isMapCameraUserControlled = false

    var body: some View {
        GeometryReader { geometry in
            if geometry.size.width > geometry.size.height {
                HStack(spacing: 0) {
                    mapSurface
                        .frame(width: geometry.size.width * 0.74)
                    landscapeControlPanel
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else {
                VStack(spacing: 0) {
                    mapSurface
                        .frame(height: geometry.size.height * 0.74)
                    portraitControlPanel
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .background(Color(.systemBackground))
        .alert("Charts Unavailable", isPresented: $showsChartsUnavailable) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Chart presentation is a later delivery. The imported plan remains unchanged.")
        }
    }

    private var mapSurface: some View {
        ZStack {
            OfflineAviationMapView(
                presentation: mapPresentation,
                legState: session.legState,
                focusRequest: mapFocusRequest,
                preservedCamera: $preservedMapCamera,
                isCameraUserControlled: $isMapCameraUserControlled
            )
            mapControls
            legHeader
        }
        .clipped()
    }

    private var legHeader: some View {
        HStack(spacing: 16) {
            HStack(spacing: 12) {
                Text(data.legPosition.uppercased()).font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                Text("·").foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    Text(data.origin).lineLimit(1)
                    Image(systemName: "arrow.right").font(.caption)
                    Text(data.destination).lineLimit(1)
                }
                .font(.headline).minimumScaleFactor(0.7)
                .environment(\.layoutDirection, .leftToRight)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("From \(data.origin) to \(data.destination)")
            }
            Spacer(minLength: 8)
            Button { showsChartsUnavailable = true } label: {
                Label("Charts", systemImage: "map").font(.headline).frame(minHeight: 44).padding(.horizontal, 12)
            }
            .buttonStyle(.plain).foregroundStyle(.primary)
        }
        .padding(.horizontal, 16).padding(.vertical, 6)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .overlay { RoundedRectangle(cornerRadius: 14).strokeBorder(.primary.opacity(0.08)) }
        .frame(maxHeight: .infinity, alignment: .top).padding(20)
    }

    private var mapControls: some View {
        VStack(spacing: 8) {
            mapFocusButton(icon: "location.north.line.fill", label: "Focus Leg", mode: .leg)
            mapFocusButton(icon: "scope", label: "Focus Waypoint", mode: .waypoint)
            mapFocusButton(icon: "map", label: "Route Overview", mode: .overview)
            Button(action: onShowPlanInspection) {
                Image(systemName: "list.bullet.clipboard").font(.headline).frame(width: 44, height: 44)
                    .background(Color(.tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 9))
            }
            .buttonStyle(.plain).accessibilityLabel("Plan Inspection").accessibilityIdentifier("show-plan-inspection")
        }
        .padding(8).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        .padding(.top, 96).padding(.trailing, 20)
    }

    private func mapFocusButton(
        icon: String,
        label: String,
        mode: AviationMapFocusMode
    ) -> some View {
        Button {
            isMapCameraUserControlled = false
            mapFocusRequest = AviationMapFocusRequest(mode: mode)
        } label: {
            Image(systemName: icon).font(.headline).frame(width: 44, height: 44)
                .background(Color(.tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 9))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private func disabledMapControl(icon: String, label: String) -> some View {
        Button {} label: {
            Image(systemName: icon).font(.headline).frame(width: 44, height: 44)
                .background(Color(.tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 9))
        }
        .buttonStyle(.plain).disabled(true).accessibilityLabel(label)
    }

    private var portraitControlPanel: some View {
        VStack(spacing: 9) {
            HStack(alignment: .top, spacing: 0) {
                headingMetric
                timeMetric
                altitudeMetric
            }
            frequencyRow
            waypointReachedButton
        }
        .padding(.horizontal, 24).padding(.top, 6).padding(.bottom, 10)
    }

    private var landscapeControlPanel: some View {
        VStack(spacing: 14) {
            headingMetric
            Divider()
            timeMetric
            Divider()
            altitudeMetric
            Divider()
            frequencyColumn
            Spacer(minLength: 8)
            waypointReachedButton
        }
        .padding(.horizontal, 18).padding(.vertical, 20)
        .background(Color(.systemBackground)).overlay(alignment: .leading) { Divider() }
    }

    private var headingMetric: some View {
        VStack(spacing: 3) {
            Text(data.magneticHeadingDegrees == nil ? "COURSE · MAGNETIC" : "HEADING · MAGNETIC")
                .font(.caption.weight(.semibold)).tracking(0.8).foregroundStyle(.secondary)
            Text(CockpitPresentationFormatter.aviationDegrees(data.magneticHeadingDegrees ?? data.magneticCourseDegrees))
                .font(.system(size: 30, weight: .semibold, design: .rounded)).monospacedDigit().lineLimit(1)
            if data.magneticHeadingDegrees == nil {
                Text("Saved course · No planned heading")
                    .font(.caption).foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.7)
            } else {
                Text("COURSE \(CockpitPresentationFormatter.aviationDegrees(data.magneticCourseDegrees))")
                    .font(.subheadline.weight(.semibold)).foregroundStyle(.secondary).monospacedDigit().lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity).accessibilityElement(children: .combine).accessibilityIdentifier("cockpit-heading")
    }

    private var timeMetric: some View {
        CockpitTimeMetric(
            plannedDurationSeconds: data.legDurationSeconds,
            legStartedAt: session.legStartedAt
        )
    }

    private var altitudeMetric: some View {
        VStack(spacing: 3) {
            Text("ALTITUDE").font(.caption.weight(.semibold)).tracking(1).foregroundStyle(.secondary)
            Text("\(Self.feet(data.initialAltitudeFeetMsl)) ft")
                .font(.system(size: 30, weight: .semibold, design: .rounded)).monospacedDigit().lineLimit(1)
            Text("Initial planned · MSL").font(.caption).foregroundStyle(.secondary).lineLimit(1)
        }
        .frame(maxWidth: .infinity).accessibilityElement(children: .combine).accessibilityIdentifier("cockpit-altitude")
    }

    private var orderedFrequencies: [CockpitPresentationData.DisplayFrequency] {
        data.displayFrequencies
    }

    private var frequencyRow: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 18) {
                Text("PLANNED FREQUENCIES").font(.caption2.weight(.bold)).tracking(0.7).foregroundStyle(.secondary)
                ForEach(orderedFrequencies) { frequencyValue($0) }
                if orderedFrequencies.isEmpty { Text("None").font(.caption).foregroundStyle(.secondary) }
                Text("Not tuned").font(.caption).foregroundStyle(.secondary)
            }
        }
        .scrollIndicators(.hidden).frame(minHeight: 30).padding(.horizontal, 10)
        .overlay(alignment: .top) { Divider() }.overlay(alignment: .bottom) { Divider() }
    }

    private var frequencyColumn: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("PLANNED FREQUENCIES").font(.caption2.weight(.bold)).tracking(0.7).foregroundStyle(.secondary)
                Spacer(); Text("Not tuned").font(.caption).foregroundStyle(.secondary)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 7) {
                    ForEach(orderedFrequencies) { frequencyValue($0) }
                    if orderedFrequencies.isEmpty { Text("None").font(.caption).foregroundStyle(.secondary) }
                }
            }
            .frame(maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func frequencyValue(_ frequency: CockpitPresentationData.DisplayFrequency) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 7) {
                Text("\(frequency.service) · \(frequency.serviceType)")
                    .font(.subheadline).lineLimit(1).minimumScaleFactor(0.8)
                Text("\(Self.frequency(frequency.frequencyMHz)) MHz")
                    .font(.subheadline.weight(.semibold)).monospacedDigit().lineLimit(1)
            }
            Text(frequency.phases.map(Self.phaseAbbreviation).joined(separator: " → "))
                .font(.caption2.weight(.bold)).foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var waypointReachedButton: some View {
        if session.legState == .ready {
            Button(action: onStartLeg) {
                Label("Start Leg", systemImage: "play.fill")
                    .font(.headline).frame(maxWidth: .infinity, minHeight: 50)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityHint("Starts timing the current navigation leg")
            .accessibilityIdentifier("start-leg")
        } else {
            Button {} label: {
                Label("Waypoint Reached", systemImage: "checkmark.circle.fill")
                    .font(.headline).frame(maxWidth: .infinity, minHeight: 50)
            }
            .buttonStyle(.plain).foregroundStyle(.secondary)
            .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 10))
            .disabled(true)
            .accessibilityHint("Waypoint progression is not implemented in this delivery")
            .accessibilityIdentifier("waypoint-reached")
        }
    }

    private static func feet(_ value: Double) -> String { value.formatted(.number.precision(.fractionLength(0))) }
    private static func frequency(_ value: Double) -> String { value.formatted(.number.precision(.fractionLength(2...3))) }
    nonisolated private static func phaseAbbreviation(_ phase: FlightPhase) -> String {
        switch phase { case .departure: "DEP"; case .enRoute: "ENR"; case .arrival: "ARR" }
    }
}

private struct CockpitTimeMetric: View {
    let plannedDurationSeconds: Int
    let legStartedAt: Date?

    var body: some View {
        if let legStartedAt {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                metric(
                    primaryValue: duration(elapsedSeconds(from: legStartedAt, to: context.date)),
                    primaryLabel: "ELAPSED",
                    secondaryValue: "PLAN \(duration(plannedDurationSeconds))"
                )
            }
        } else {
            metric(
                primaryValue: duration(plannedDurationSeconds),
                primaryLabel: "PLANNED",
                secondaryValue: "Elapsed  --:--"
            )
        }
    }

    private func metric(
        primaryValue: String,
        primaryLabel: LocalizedStringKey,
        secondaryValue: String
    ) -> some View {
        VStack(spacing: 2) {
            Text("TIME").font(.caption.weight(.semibold)).tracking(1).foregroundStyle(.secondary)
            Text(primaryValue)
                .font(.system(size: 32, weight: .semibold, design: .rounded)).monospacedDigit().lineLimit(1)
            Text(primaryLabel).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            Text(secondaryValue).font(.subheadline.weight(.semibold)).foregroundStyle(.secondary).monospacedDigit()
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("cockpit-time")
    }

    private func elapsedSeconds(from start: Date, to now: Date) -> Int {
        max(0, Int(now.timeIntervalSince(start)))
    }

    private func duration(_ seconds: Int) -> String {
        String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}
