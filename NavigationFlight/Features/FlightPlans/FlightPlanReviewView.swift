import SwiftUI

struct FlightPlanReviewPresentation: Equatable {
    struct Leg: Identifiable, Equatable {
        let id: UUID
        let index: Int
        let departure: String
        let destination: String
        let route: String
        let distance: String
        let duration: String
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
    let frequencyPlan: CockpitFrequencyPlan
    let communicationPlan: CockpitOperationalCueState.CommunicationPlan?
    let frequencyReferences: [CockpitPresentationData.PlannedReference]
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
                departure: leg.departure.name,
                destination: leg.arrival.name,
                route: "\(leg.departure.name) → \(leg.arrival.name)",
                distance: values.map { "\($0.groundDistance.value.formatted(.number.precision(.fractionLength(1)))) NM" } ?? "Unavailable",
                duration: values.map { Self.duration($0.noWind.durationSeconds) } ?? "Unavailable"
            )
        }

        let frequencies = Dictionary(uniqueKeysWithValues: FlightPhase.allCases.map { phase in
            (phase, (planned?.frequenciesByPhase[phase] ?? []).map {
                CockpitPresentationData.Frequency(
                    id: $0.id,
                    phase: phase,
                    role: $0.role,
                    service: $0.name,
                    frequencyMHz: $0.frequency.value,
                    source: $0.source
                )
            })
        })
        let sourceReferences = Dictionary(uniqueKeysWithValues: plan.vorDmeReferences.map { ($0.id, $0) })
        let waypointNames = Dictionary(uniqueKeysWithValues: plan.waypoints.map { ($0.id, $0.name) })
        let references: [CockpitPresentationData.PlannedReference] = (planned?.vorDmeReferences ?? []).compactMap { resolved in
            guard let source = sourceReferences[resolved.referenceID],
                  let endpointName = waypointNames[source.waypointID] else { return nil }
            return CockpitPresentationData.PlannedReference(
                id: resolved.referenceID,
                endpointName: endpointName,
                station: source.navigationAid.identifier,
                frequencyMHz: resolved.frequency.value,
                magneticRadialFromDegrees: resolved.magneticRadialFrom.value,
                slantRangeNauticalMiles: resolved.slantRange.value,
                source: resolved.source
            )
        }
        frequencyPlan = CockpitPresentationAdapter().makeFrequencyPlan(
            frequencies: frequencies,
            references: references
        )
        frequencyReferences = references
        communicationPlan = Self.readyCommunicationPlan(
            flightPlan: plan,
            frequencies: frequencies
        )

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

    private static func readyCommunicationPlan(
        flightPlan: FlightPlan,
        frequencies: [FlightPhase: [CockpitPresentationData.Frequency]]
    ) -> CockpitOperationalCueState.CommunicationPlan {
        let changeByID = flightPlan.frequencyChanges.reduce(into: [String: FrequencyChange]()) {
            $0["route:\($1.id.uuidString.lowercased())"] = $1
        }
        let legByID = flightPlan.legs.reduce(into: [UUID: NavigationLeg]()) {
            $0[$1.id] = $1
        }
        let entries = FlightPhase.allCases.flatMap { phase in
            (frequencies[phase] ?? []).filter {
                $0.source != .vorDme && $0.frequencyMHz >= 118
            }.map { frequency -> CockpitOperationalCueState.CommunicationPlan.Entry in
                let state: CockpitOperationalCueState.CommunicationPlan.Entry.State
                let dueContext: String
                switch phase {
                case .departure:
                    state = .departurePlan
                    dueContext = "Before navigation"
                case .arrival:
                    state = .arrival
                    dueContext = "After navigation"
                case .enRoute:
                    if let change = changeByID[frequency.id],
                       let leg = legByID[change.legID] {
                        state = change.progress.fraction == 0 ? .atStart : .later
                        dueContext = "\(leg.departure.name) → \(leg.arrival.name) · "
                            + (change.progress.fraction == 0 ? "at start" : "later this leg")
                    } else {
                        state = .later
                        dueContext = "Planned in route"
                    }
                }
                return CockpitOperationalCueState.CommunicationPlan.Entry(
                    id: frequency.id,
                    phase: frequency.phase,
                    role: frequency.role,
                    service: frequency.service,
                    frequencyMHz: frequency.frequencyMHz,
                    state: state,
                    dueContext: dueContext
                )
            }
        }
        let departureEntries = entries.filter { $0.phase == .departure }
        let enRouteEntries = entries.filter { $0.phase == .enRoute }
        let compactEntries = Array((Array(departureEntries.prefix(1)) + Array(enRouteEntries.prefix(2))).prefix(3))
        return .init(entries: entries, compactEntries: compactEntries)
    }
}

struct FlightPlanReviewView: View {
    private enum PresentedSheet: String, Identifiable {
        case frequencyPlan
        case routeDetails

        var id: String { rawValue }
    }

    let record: LibraryFlightPlan
    let loadedFlightPlan: FlightPlan?
    let isActionDisabled: Bool
    let primaryAction: FlightPlanInspectionPresentation.PresentedAction
    let updateActions: [FlightPlanInspectionPresentation.PresentedAction]
    let flightActions: [FlightPlanInspectionPresentation.PresentedAction]
    let onAction: (FlightPlanInspectionPresentation.Action) -> Void
    let onRemove: () -> Void

    @State private var presentedSheet: PresentedSheet?
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
        .accessibilityHidden(presentedSheet == .frequencyPlan)
        .overlay {
            if presentedSheet == .frequencyPlan {
                frequencyPlanOverlay
            }
        }
        .sheet(isPresented: routeDetailsBinding) {
            FlightPlanRouteDetailsView(presentation: presentation) {
                presentedSheet = nil
            }
            .presentationDetents([.large])
        }
        .accessibilityIdentifier("flight-plan-inspection")
    }

    private var routeDetailsBinding: Binding<Bool> {
        Binding(
            get: { presentedSheet == .routeDetails },
            set: { isPresented in
                if !isPresented { presentedSheet = nil }
            }
        )
    }

    private var frequencyPlanOverlay: some View {
        ZStack {
            Button {
                presentedSheet = nil
            } label: {
                Color.black.opacity(0.22)
                    .ignoresSafeArea()
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close frequency plan")

            CockpitFrequencyPlanView(
                plan: presentation.frequencyPlan,
                communicationPlan: presentation.communicationPlan,
                references: presentation.frequencyReferences
            ) {
                presentedSheet = nil
            }
            .frame(maxWidth: 690, maxHeight: 760)
            .clipShape(RoundedRectangle(cornerRadius: 28))
            .shadow(color: .black.opacity(0.2), radius: 18, y: 8)
            .padding(24)
            .accessibilityElement(children: .contain)
            .accessibilityAddTraits(.isModal)
            .accessibilitySortPriority(1)
        }
        .accessibilityIdentifier("flight-plan-frequency-overlay")
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
    }

    private var frequencySummary: some View {
        Button {
            presentedSheet = .frequencyPlan
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Label("Frequency Plan", systemImage: "chevron.right")
                    .font(.headline)
                Text(presentation.frequencyPlan.entries.isEmpty ? "No planned frequencies" : "Complete imported sequence · planning data")
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
                presentedSheet = .routeDetails
            } label: {
                Label("Route", systemImage: "chevron.right")
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

    private func identifier(for action: FlightPlanInspectionPresentation.Action) -> String {
        switch action {
        case .loadInCockpit: "load-in-cockpit"
        case .returnToCockpit: "return-to-cockpit"
        case .loadUpdatedPlan: "load-updated-plan"
        case .restartFlight: "restart-flight"
        }
    }
}

private struct FlightPlanRouteDetailsView: View {
    let presentation: FlightPlanReviewPresentation
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
                .padding(.top, 10)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    endpoints
                    ForEach(presentation.legs) { leg in
                        legCard(leg)
                    }
                    Text("\(presentation.distance) total · \(presentation.duration) no-wind ETE")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 16)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 18)
        .background(Color(.systemBackground))
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text("Route details")
                    .font(.title2.bold())
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Button("Close", action: onClose)
                    .font(.subheadline.weight(.semibold))
                    .accessibilityIdentifier("close-route-details")
            }
            Text("Read-only saved route order")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var endpoints: some View {
        HStack {
            endpoint("DEPARTURE", presentation.departure, alignment: .leading)
            Spacer()
            Image(systemName: "arrow.right")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Spacer()
            endpoint("DESTINATION", presentation.destination, alignment: .trailing)
        }
        .padding(13)
        .background(Color(.secondarySystemBackground), in: .rect(cornerRadius: 11))
        .accessibilityElement(children: .combine)
    }

    private func endpoint(_ label: LocalizedStringKey, _ value: String, alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 3) {
            Text(label)
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
        }
    }

    private func legCard(_ leg: FlightPlanReviewPresentation.Leg) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Text("\(leg.index)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(Color.accentColor, in: .circle)
                Text(leg.departure)
                Image(systemName: "arrow.right")
                    .accessibilityHidden(true)
                Text(leg.destination)
            }
            .font(.headline)

            HStack {
                Text(leg.distance)
                    .fontWeight(.semibold)
                Spacer()
                Text("\(leg.duration) · No wind")
                    .foregroundStyle(.secondary)
            }
            .font(.subheadline)
            .monospacedDigit()
        }
        .frame(maxWidth: .infinity, minHeight: 68, alignment: .leading)
        .padding(13)
        .background(Color(.secondarySystemBackground), in: .rect(cornerRadius: 11))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("route-detail-leg-\(leg.index)")
    }
}
