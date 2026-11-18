import SwiftUI

struct CockpitFrequencyPlanView: View {
    let plan: CockpitFrequencyPlan
    var communicationPlan: CockpitOperationalCueState.CommunicationPlan? = nil
    var navigationAidPlan: CockpitOperationalCueState.NavigationAidPlan? = nil
    var references: [CockpitPresentationData.PlannedReference] = []
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
                .padding(.top, 10)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    if !hasCommunications && navigationAidStations.isEmpty {
                        ContentUnavailableView(
                            "No Planned Frequencies",
                            systemImage: "radio",
                            description: Text("The imported plan contains no communication or navigation-aid frequencies.")
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.top, 48)
                    } else {
                        if communicationPlan == nil {
                            ForEach(plan.entries.filter { $0.kind == .communication }) { entry in
                                CockpitFrequencyPlanEntryView(entry: entry)
                            }
                        } else if !communicationEntries.isEmpty {
                            Text("COMMUNICATIONS")
                                .font(.caption.weight(.bold))
                                .tracking(0.7)
                                .foregroundStyle(.secondary)
                                .accessibilityAddTraits(.isHeader)
                            ForEach(FlightPhase.allCases, id: \.rawValue) { phase in
                                let entries = communicationEntries.filter { $0.phase == phase }
                                if !entries.isEmpty {
                                    Text(phaseTitle(phase))
                                        .font(.headline)
                                        .padding(.top, 8)
                                        .accessibilityAddTraits(.isHeader)
                                    ForEach(entries) { entry in
                                        CockpitCommunicationPlanEntryView(entry: entry)
                                    }
                                }
                            }
                        }
                        if !navigationAidStations.isEmpty {
                            Divider()
                                .padding(.top, 6)
                            Text("NAVIGATION AIDS")
                                .font(.caption.weight(.bold))
                                .tracking(0.7)
                                .foregroundStyle(navigationAidAccent)
                                .padding(.top, 14)
                                .accessibilityAddTraits(.isHeader)
                            ForEach(navigationAidStations) { station in
                                CockpitNavigationAidStationView(station: station)
                            }
                        }
                    }
                }
                .padding(.vertical, 16)
            }

            if hasCommunications || !navigationAidStations.isEmpty {
                Text("These values come from the imported plan. The app does not know what is tuned.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 18)
        .background(Color(.systemBackground))
    }

    private var communicationEntries: [CockpitOperationalCueState.CommunicationPlan.Entry] {
        communicationPlan?.entries ?? []
    }

    private var hasCommunications: Bool {
        if communicationPlan != nil { return !communicationEntries.isEmpty }
        return plan.entries.contains { $0.kind == .communication }
    }

    private var navigationAidStations: [CockpitOperationalCueState.NavigationAidPlan.Station] {
        if let navigationAidPlan { return navigationAidPlan.stations }

        var stations: [CockpitOperationalCueState.NavigationAidPlan.Station] = []
        for (routeIndex, reference) in references.enumerated() {
            let association = CockpitOperationalCueState.NavigationAidPlan.Association(
                id: reference.id,
                state: .later,
                arrivalWaypoint: reference.endpointName,
                routeIndex: routeIndex
            )
            if let index = stations.firstIndex(where: {
                $0.identifier == reference.station && $0.frequencyMHz == reference.frequencyMHz
            }) {
                let station = stations[index]
                stations[index] = .init(
                    id: station.id,
                    identifier: station.identifier,
                    frequencyMHz: station.frequencyMHz,
                    associations: station.associations + [association]
                )
            } else {
                stations.append(.init(
                    id: reference.id,
                    identifier: reference.station,
                    frequencyMHz: reference.frequencyMHz,
                    associations: [association]
                ))
            }
        }
        return stations
    }

    private var navigationAidAccent: Color {
        Color(red: 91 / 255, green: 79 / 255, blue: 179 / 255)
    }

    private func phaseTitle(_ phase: FlightPhase) -> String {
        switch phase {
        case .departure: "Departure"
        case .enRoute: "En route"
        case .arrival: "Arrival"
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text("Frequency plan")
                    .font(.title2.bold())
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("frequency-plan-title")
                Spacer()
                Button("Close", action: onClose)
                    .font(.subheadline.weight(.semibold))
                    .accessibilityIdentifier("close-frequency-plan")
            }
            Text("Imported planning data—not live radio state")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

private struct CockpitNavigationAidStationView: View {
    let station: CockpitOperationalCueState.NavigationAidPlan.Station

    private let accent = Color(red: 91 / 255, green: 79 / 255, blue: 179 / 255)
    private let background = Color(red: 241 / 255, green: 239 / 255, blue: 254 / 255)
    private let border = Color(red: 199 / 255, green: 194 / 255, blue: 243 / 255)

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text("V")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(cardAccent, in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 8) {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(station.identifier)
                            .font(.subheadline.weight(.bold))
                        Spacer(minLength: 8)
                        frequencyText
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(station.identifier)
                            .font(.subheadline.weight(.bold))
                        frequencyText
                    }
                }

                if let displayedAssociation {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(stateLabel)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(cardAccent)
                        Text(waypointSummary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(accessibilityLabel)
                    .accessibilityIdentifier("navigation-aid-association-summary-\(displayedAssociation.id.uuidString.lowercased())")
                }
                Text("Plan reference · receiver state unknown")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
        .padding(11)
        .background(cardBackground, in: RoundedRectangle(cornerRadius: 12))
        .overlay { RoundedRectangle(cornerRadius: 12).strokeBorder(cardBorder) }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(station.identifier), \(formattedFrequency) megahertz, VOR/DME")
        .accessibilityIdentifier("navigation-aid-station-\(station.id.uuidString.lowercased())")
    }

    private var frequencyText: some View {
        Text("\(formattedFrequency) MHz")
            .font(.subheadline.weight(.bold))
            .monospacedDigit()
    }

    private var formattedFrequency: String {
        station.frequencyMHz.formatted(.number.precision(.fractionLength(3)))
    }

    private var remainingAssociations: [CockpitOperationalCueState.NavigationAidPlan.Association] {
        station.associations.filter { $0.state != .history }
    }

    private var displayedAssociation: CockpitOperationalCueState.NavigationAidPlan.Association? {
        remainingAssociations.first ?? station.associations.last
    }

    private var remainingWaypoints: [String] {
        remainingAssociations.reduce(into: []) { waypoints, association in
            guard !waypoints.contains(association.arrivalWaypoint) else { return }
            waypoints.append(association.arrivalWaypoint)
        }
    }

    private var isPassed: Bool { remainingAssociations.isEmpty }
    private var isCurrent: Bool { displayedAssociation?.state == .current }

    private var waypointSummary: String {
        guard let displayedAssociation else { return "" }
        if isPassed { return "Last used at \(displayedAssociation.arrivalWaypoint)" }

        let first = displayedAssociation.arrivalWaypoint
        let additionalCount = remainingWaypoints.count - 1
        guard additionalCount > 0 else { return "For arrival at \(first)" }
        let noun = additionalCount == 1 ? "other waypoint" : "other waypoints"
        return "For arrival at \u{2068}\(first)\u{2069} + \(additionalCount) \(noun)"
    }

    private var stateLabel: String {
        guard !isPassed, let state = displayedAssociation?.state else { return "PASSED · VOR/DME" }
        return switch state {
        case .firstFlownLeg: "PLANNED FOR FIRST FLOWN LEG · VOR/DME"
        case .upcomingLeg: "UPCOMING LEG REFERENCE · VOR/DME"
        case .current: "PLANNED CURRENT · VOR/DME"
        case .later: "LATER · VOR/DME"
        case .history: "PASSED · VOR/DME"
        }
    }

    private var accessibilityLabel: String {
        guard let displayedAssociation else { return "Plan reference, receiver state unknown" }
        if isPassed {
            return "Passed, last used at \(displayedAssociation.arrivalWaypoint), plan reference, receiver state unknown"
        }
        let waypoints = remainingWaypoints.joined(separator: ", ")
        return "\(accessibilityStateLabel(for: displayedAssociation.state)), for arrival at \(waypoints), plan reference, receiver state unknown"
    }

    private var cardAccent: Color {
        if isPassed { return .secondary }
        if isCurrent { return .green }
        return accent
    }

    private var cardBackground: Color {
        if isPassed { return Color(.secondarySystemBackground) }
        if isCurrent { return Color.green.opacity(0.12) }
        return background
    }

    private var cardBorder: Color {
        if isPassed { return Color.secondary.opacity(0.2) }
        if isCurrent { return Color.green.opacity(0.35) }
        return border
    }

    private func accessibilityStateLabel(for state: CockpitOperationalCueState.NavigationAidPlan.Association.State) -> String {
        switch state {
        case .firstFlownLeg: "Planned for first flown leg"
        case .upcomingLeg: "Upcoming leg reference"
        case .current: "Planned current"
        case .later: "Later"
        case .history: "Planned history"
        }
    }
}

private struct CockpitCommunicationPlanEntryView: View {
    let entry: CockpitOperationalCueState.CommunicationPlan.Entry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(stateLabel)
                .font(.caption.weight(.semibold))
                .foregroundStyle(isCurrent ? Color.green : .secondary)
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(serviceDescription)
                    .font(.subheadline.weight(.semibold))
                Spacer(minLength: 8)
                Text("\(entry.frequencyMHz.formatted(.number.precision(.fractionLength(3)))) MHz")
                    .font(.headline)
                    .monospacedDigit()
            }
            Text(entry.dueContext)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
        .padding(12)
        .background(isCurrent ? Color.green.opacity(0.12) : Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(stateLabel), \(serviceDescription), \(entry.frequencyMHz.formatted(.number.precision(.fractionLength(3)))) megahertz, communication, \(entry.dueContext)")
        .accessibilityIdentifier("communication-plan-entry-\(entry.id)")
    }

    private var isCurrent: Bool { entry.state == .current }

    private var stateLabel: String {
        switch entry.state {
        case .departurePlan: "Departure plan"
        case .atStart: "Planned at start"
        case .current: "Planned now"
        case .next: "Planned next"
        case .later: "Planned later"
        case .past: "Planned history"
        case .arrival: "Planned after navigation"
        }
    }

    private var serviceDescription: String {
        guard let role = entry.role, !role.isEmpty else { return entry.service }
        return "\(entry.service) · \(role)"
    }
}

private struct CockpitFrequencyPlanEntryView: View {
    let entry: CockpitFrequencyPlan.Entry

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(sequenceLabel)
                    .font(.subheadline.weight(.semibold))
                Spacer(minLength: 8)
                Text(entry.frequencyMHz, format: .number.precision(.fractionLength(3)))
                    .font(.headline)
                    .monospacedDigit()
            }
            Text(serviceDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(associationLabel)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .padding(.horizontal, 13)
        .padding(.vertical, 9)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 11))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(sequenceLabel), \(serviceDescription), \(entry.frequencyMHz.formatted(.number.precision(.fractionLength(3)))) megahertz, \(associationLabel)")
        .accessibilityIdentifier("frequency-plan-entry-\(entry.id)")
    }

    private var sequenceLabel: String {
        switch entry.sequence {
        case .now: "Planned now"
        case .next: "Planned next"
        case .later: "Planned later"
        }
    }

    private var serviceDescription: String {
        guard let role = entry.role, !role.isEmpty else { return entry.service }
        return "\(entry.service) · \(role)"
    }

    private var associationLabel: String {
        switch entry.kind {
        case .communication: "Planned for \(entry.association)"
        case .navigationAid: "Navigation aid · planned for \(entry.association)"
        }
    }
}
