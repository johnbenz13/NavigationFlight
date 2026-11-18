import SwiftUI

struct CockpitFrequencyPlanView: View {
    let plan: CockpitFrequencyPlan
    var communicationPlan: CockpitOperationalCueState.CommunicationPlan? = nil
    var references: [CockpitPresentationData.PlannedReference] = []
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
                .padding(.top, 10)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    if plan.entries.isEmpty && communicationEntries.isEmpty {
                        ContentUnavailableView(
                            "No Planned Frequencies",
                            systemImage: "radio",
                            description: Text("The imported plan contains no communication or navigation-aid frequencies.")
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.top, 48)
                    } else {
                        if communicationPlan == nil {
                            ForEach(plan.entries) { entry in
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
                        if !navigationAidEntries.isEmpty {
                            Text("NAVIGATION AIDS")
                                .font(.caption.weight(.bold))
                                .tracking(0.7)
                                .foregroundStyle(.secondary)
                                .padding(.top, 14)
                                .accessibilityAddTraits(.isHeader)
                            ForEach(navigationAidEntries) { entry in
                                CockpitFrequencyPlanEntryView(entry: entry)
                            }
                        }
                    }
                }
                .padding(.vertical, 16)
            }

            if !plan.entries.isEmpty || !communicationEntries.isEmpty {
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

    private var navigationAidEntries: [CockpitFrequencyPlan.Entry] {
        var entries = plan.entries.filter { $0.kind == .navigationAid }
        for reference in references where !entries.contains(where: {
            $0.service == reference.station && $0.frequencyMHz == reference.frequencyMHz
        }) {
            entries.append(.init(
                id: "reference:\(reference.id.uuidString.lowercased())",
                sequence: .later,
                kind: .navigationAid,
                service: reference.station,
                role: "VOR/DME",
                frequencyMHz: reference.frequencyMHz,
                association: reference.endpointName
            ))
        }
        return entries
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
