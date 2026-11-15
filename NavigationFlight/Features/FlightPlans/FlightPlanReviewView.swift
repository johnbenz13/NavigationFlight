import SwiftUI

struct FlightPlanReviewPresentation: Equatable {
    struct Leg: Identifiable, Equatable {
        let id: UUID
        let index: Int
        let route: String
        let distance: String
        let duration: String
    }

    struct FrequencySection: Identifiable, Equatable {
        let phase: FlightPhase
        let values: [String]

        var id: FlightPhase { phase }
    }

    let title: String
    let status: String
    let provenance: String
    let departure: String
    let destination: String
    let revision: Date
    let imported: Date
    let distance: String
    let duration: String
    let legs: [Leg]
    let frequencySections: [FrequencySection]
    let map: AviationMapPresentation?

    init(record: LibraryFlightPlan, isLoaded: Bool) {
        let plan = record.flightPlan
        let planned = plan.plannedNavigation.plannedNavigation
        let plannedLegs = (planned?.legs ?? []).reduce(into: [UUID: PlannedLegNavigation]()) {
            $0[$1.legID] = $1
        }

        title = plan.title
        status = isLoaded ? "Current loaded Flight" : "Saved Flight Plan"
        provenance = "Imported planning data · No wind"
        departure = plan.waypoints.first?.name ?? "Unavailable"
        destination = plan.waypoints.last?.name ?? "Unavailable"
        revision = plan.modifiedAt
        imported = record.importedAt

        let totalDistance = planned?.legs.reduce(0.0) { $0 + $1.groundDistance.value }
        let totalDuration = planned?.legs.reduce(0) { $0 + $1.noWind.durationSeconds }
        distance = totalDistance.map { "\($0.formatted(.number.precision(.fractionLength(1)))) NM" } ?? "Unavailable"
        duration = totalDuration.map { Self.duration($0) } ?? "Unavailable"

        legs = plan.legs.enumerated().map { index, leg in
            let values = plannedLegs[leg.id]
            return Leg(
                id: leg.id,
                index: index + 1,
                route: "\(leg.departure.name) → \(leg.arrival.name)",
                distance: values.map { "\($0.groundDistance.value.formatted(.number.precision(.fractionLength(1)))) NM" } ?? "Unavailable",
                duration: values.map { Self.duration($0.noWind.durationSeconds) } ?? "Unavailable"
            )
        }

        frequencySections = FlightPhase.allCases.compactMap { phase in
            let values = (planned?.frequenciesByPhase[phase] ?? []).map { frequency in
                let role = frequency.role.map { " · \($0)" } ?? ""
                return "\(frequency.name)\(role) · \(frequency.frequency.value.formatted(.number.precision(.fractionLength(2...3)))) MHz"
            }
            return values.isEmpty ? nil : FrequencySection(phase: phase, values: values)
        }

        if let firstLeg = plan.legs.first, let lastLeg = plan.legs.last {
            let waypoints = plan.waypoints.map { waypoint in
                AviationMapWaypoint(
                    id: waypoint.id,
                    name: waypoint.name,
                    coordinate: AviationMapCoordinate(
                        latitude: waypoint.position.latitudeDegrees,
                        longitude: waypoint.position.longitudeDegrees
                    ),
                    role: waypoint.id == firstLeg.departure.id
                        ? .from
                        : (waypoint.id == lastLeg.arrival.id ? .to : .route)
                )
            }
            let mapLegs = plan.legs.enumerated().map { index, leg in
                AviationMapLeg(
                    id: leg.id,
                    index: index,
                    from: AviationMapCoordinate(
                        latitude: leg.departure.position.latitudeDegrees,
                        longitude: leg.departure.position.longitudeDegrees
                    ),
                    to: AviationMapCoordinate(
                        latitude: leg.arrival.position.latitudeDegrees,
                        longitude: leg.arrival.position.longitudeDegrees
                    )
                )
            }
            map = AviationMapPresentation(
                waypoints: waypoints,
                legs: mapLegs,
                activeLegIndex: 0,
                nextLegPreview: nil,
                endpointReferences: [],
                plannedDurationSeconds: totalDuration ?? 0,
                minuteMarkers: [],
                identificationPoints: [],
                destinationTarget: AviationMapETATarget(
                    id: NavigationTimingTargetKey(
                        legID: lastLeg.id,
                        kind: .destination,
                        targetID: lastLeg.arrival.id
                    ),
                    name: lastLeg.arrival.name,
                    plannedElapsedSeconds: totalDuration ?? 0,
                    committedETASeconds: nil
                ),
                driftReferenceArms: []
            )
        } else {
            map = nil
        }
    }

    private static func duration(_ seconds: Int) -> String {
        let hours = seconds / 3_600
        let minutes = (seconds % 3_600) / 60
        return hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes)m"
    }
}

struct FlightPlanReviewView: View {
    let record: LibraryFlightPlan
    let loadedFlightPlan: FlightPlan?
    let isActionDisabled: Bool
    let primaryAction: FlightPlanInspectionPresentation.PresentedAction
    let updateActions: [FlightPlanInspectionPresentation.PresentedAction]
    let flightActions: [FlightPlanInspectionPresentation.PresentedAction]
    let onAction: (FlightPlanInspectionPresentation.Action) -> Void
    let onRemove: () -> Void

    @State private var isRouteExpanded = false
    @State private var isFrequencyExpanded = false
    @State private var mapFocusRequest = AviationMapFocusRequest(mode: .overview)
    @State private var preservedMapCamera: AviationMapCameraState?
    @State private var isMapCameraUserControlled = false
    @State private var destinationCalloutOffset = AviationMapCalloutOffset(x: 0, y: 0)
    @State private var destinationVORCalloutOffset = AviationMapCalloutOffset(x: 0, y: 0)
    @State private var identificationPointCalloutOffsets: [IdentificationPointKey: AviationMapCalloutOffset] = [:]

    private var presentation: FlightPlanReviewPresentation {
        FlightPlanReviewPresentation(
            record: record,
            isLoaded: record.id == loadedFlightPlan?.id
        )
    }

    var body: some View {
        GeometryReader { proxy in
            if proxy.size.width > proxy.size.height {
                HStack(spacing: 0) {
                    mapSurface
                        .frame(width: proxy.size.width * 0.61)
                    reviewSurface
                }
            } else {
                VStack(spacing: 0) {
                    mapSurface
                        .frame(height: min(proxy.size.height * 0.44, 520))
                    reviewSurface
                }
            }
        }
        .background(Color(.systemBackground))
        .navigationTitle(presentation.title)
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("flight-plan-inspection")
    }

    private var mapSurface: some View {
        ZStack(alignment: .topTrailing) {
            if let map = presentation.map {
                OfflineAviationMapView(
                    presentation: map,
                    legState: .ready,
                    showsDriftReferenceArms: false,
                    focusRequest: mapFocusRequest,
                    placesEndpointLabelsOutward: true,
                    etaCalloutOffset: $destinationCalloutOffset,
                    vorDMECalloutOffset: $destinationVORCalloutOffset,
                    identificationPointCalloutOffsets: $identificationPointCalloutOffsets,
                    identificationContext: nil,
                    timingTargetContext: nil,
                    preservedCamera: $preservedMapCamera,
                    isCameraUserControlled: $isMapCameraUserControlled,
                    onSelectIdentificationPoint: { _ in },
                    onSelectTimingTarget: { _ in },
                    onDismissCallout: {},
                    onReachIdentificationPoint: {},
                    onAdjustPilotETA: { _, _ in },
                    onCommitPilotETA: { _ in },
                    onEditPilotETA: { _ in },
                    onShowPilotETACheck: { _ in },
                    onHidePilotETACheck: { _ in },
                    onMapInteraction: {}
                )
                .accessibilityLabel("Route overview from \(presentation.departure) to \(presentation.destination), \(presentation.legs.count) legs")
                .accessibilityIdentifier("flight-plan-review-map")
            } else {
                ContentUnavailableView(
                    "Route geometry unavailable",
                    systemImage: "map",
                    description: Text("Saved plan information remains available below.")
                )
                .accessibilityIdentifier("flight-plan-review-map-unavailable")
            }

            VStack(alignment: .trailing, spacing: 12) {
                Button("Fit route", systemImage: "scope") {
                    mapFocusRequest = AviationMapFocusRequest(mode: .overview)
                }
                .buttonStyle(.bordered)
                .disabled(presentation.map == nil)
                .accessibilityIdentifier("fit-flight-plan-route")

                VStack(alignment: .leading, spacing: 3) {
                    Text(presentation.title)
                        .font(.headline)
                    Text("\(presentation.departure) → \(presentation.destination) · \(presentation.legs.count) legs")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.regularMaterial, in: .rect(cornerRadius: 16))
            }
            .padding()
        }
        .clipped()
    }

    private var reviewSurface: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(presentation.status)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(presentation.title)
                        .font(.title2.weight(.semibold))
                    Text(presentation.provenance)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                HStack(spacing: 0) {
                    metric("DISTANCE", presentation.distance)
                    Rectangle().fill(Color(.separator)).frame(width: 1, height: 54)
                    metric("ESTIMATED EN-ROUTE TIME", presentation.duration)
                    Text("No wind")
                        .font(.subheadline.weight(.medium))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(Color(.secondarySystemBackground), in: .capsule)
                }
                .padding(.vertical, 12)
                .background(Color(.secondarySystemBackground), in: .rect(cornerRadius: 14))
                .accessibilityIdentifier("flight-plan-review-summary")

                informationCard

                if isFrequencyExpanded {
                    frequencyDetails
                }
                if isRouteExpanded {
                    routeDetails
                }

                actionSection
                Divider()
                Button("Remove from Flight Plans…", role: .destructive, action: onRemove)
                    .disabled(isActionDisabled)
                    .accessibilityIdentifier("remove-flight-plan")
                Text("Removes only the saved library copy.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(20)
        }
    }

    private var informationCard: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 16) {
                frequencySummary
                Divider()
                routeSummary
                Divider()
                flightPlanSummary
            }
            VStack(alignment: .leading, spacing: 16) {
                frequencySummary
                Divider()
                routeSummary
                Divider()
                flightPlanSummary
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground), in: .rect(cornerRadius: 14))
        .accessibilityIdentifier("flight-plan-information")
    }

    private var frequencySummary: some View {
        Button {
            isFrequencyExpanded.toggle()
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Label("Frequency Plan", systemImage: isFrequencyExpanded ? "chevron.down" : "chevron.right")
                    .font(.headline)
                Text(presentation.frequencySections.isEmpty ? "No planned frequencies" : "\(presentation.frequencySections.reduce(0) { $0 + $1.values.count }) planned entries · not tuned")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(minHeight: 44)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("flight-plan-frequency-disclosure")
    }

    private var routeSummary: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                isRouteExpanded.toggle()
            } label: {
                Label("Route", systemImage: isRouteExpanded ? "chevron.down" : "chevron.right")
                    .font(.headline)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("flight-plan-route-disclosure")
            LabeledContent("Departure", value: presentation.departure)
            LabeledContent("Destination", value: presentation.destination)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var flightPlanSummary: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Flight Plan").font(.headline)
            LabeledContent("Revision") { Text(presentation.revision, format: .dateTime) }
            LabeledContent("Imported") { Text(presentation.imported, format: .dateTime) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var frequencyDetails: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Planned Frequency Sequence").font(.headline)
            if presentation.frequencySections.isEmpty {
                Text("No optional frequency information was imported.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(presentation.frequencySections) { section in
                    VStack(alignment: .leading, spacing: 5) {
                        Text(phaseTitle(section.phase))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        ForEach(section.values, id: \.self) { Text($0).font(.subheadline) }
                    }
                }
            }
            Text("Read-only imported planning information. This does not indicate a tuned or live receiver.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(Color(.secondarySystemBackground), in: .rect(cornerRadius: 14))
        .accessibilityIdentifier("flight-plan-frequency-details")
    }

    private var routeDetails: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Route Details").font(.headline)
            ForEach(presentation.legs) { leg in
                HStack(alignment: .firstTextBaseline) {
                    Text("\(leg.index)").foregroundStyle(.secondary).frame(width: 24, alignment: .leading)
                    Text(leg.route).frame(maxWidth: .infinity, alignment: .leading)
                    Text(leg.distance).monospacedDigit()
                    Text(leg.duration).monospacedDigit().frame(width: 58, alignment: .trailing)
                }
                .font(.subheadline)
                .accessibilityElement(children: .combine)
            }
            Text("Read-only saved route order.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(Color(.secondarySystemBackground), in: .rect(cornerRadius: 14))
        .accessibilityIdentifier("flight-plan-route-details")
    }

    private var actionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                onAction(primaryAction.action)
            } label: {
                Text(primaryAction.label).frame(maxWidth: .infinity, minHeight: 34)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.roundedRectangle(radius: 12))
            .disabled(isActionDisabled)
            .accessibilityIdentifier(identifier(for: primaryAction.action))

            if let consequence = primaryAction.consequence {
                Text(consequence).font(.footnote).foregroundStyle(.secondary)
            }
            ForEach(updateActions, id: \.action) { action in
                Button(action.label) { onAction(action.action) }
                    .disabled(isActionDisabled)
                    .accessibilityIdentifier(identifier(for: action.action))
            }
            if flightActions.isEmpty == false {
                Divider().padding(.vertical, 8)
                Text("Flight Actions").font(.headline)
                ForEach(flightActions, id: \.action) { action in
                    Button(action.label, role: .destructive) { onAction(action.action) }
                        .disabled(isActionDisabled)
                        .accessibilityIdentifier(identifier(for: action.action))
                    if let consequence = action.consequence {
                        Text(consequence).font(.footnote).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func metric(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label).font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
            Text(value).font(.title2.weight(.semibold)).monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 18)
        .accessibilityElement(children: .combine)
    }

    private func phaseTitle(_ phase: FlightPhase) -> String {
        switch phase { case .departure: "Departure"; case .enRoute: "En route"; case .arrival: "Arrival" }
    }

    private func identifier(for action: FlightPlanInspectionPresentation.Action) -> String {
        switch action {
        case .loadInCockpit: "load-in-cockpit"
        case .returnToCockpit: "return-to-cockpit"
        case .loadUpdatedPlan: "load-updated-plan"
        case .restartFlight: "restart-flight"
        }
    }
}
