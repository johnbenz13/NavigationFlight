import SwiftUI

struct CockpitFrequencyPlanView: View {
    let plan: CockpitFrequencyPlan
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
                .padding(.top, 10)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    if plan.entries.isEmpty {
                        ContentUnavailableView(
                            "No Planned Frequencies",
                            systemImage: "radio",
                            description: Text("The imported plan contains no communication or navigation-aid frequencies.")
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.top, 48)
                    } else {
                        ForEach(plan.entries) { entry in
                            CockpitFrequencyPlanEntryView(entry: entry)
                        }
                    }
                }
                .padding(.vertical, 16)
            }

            if !plan.entries.isEmpty {
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
