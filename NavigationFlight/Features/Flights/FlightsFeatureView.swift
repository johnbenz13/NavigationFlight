import SwiftUI

struct FlightsFeatureView: View {
    @Binding var state: FlightsFeatureState
    let library: FlightRecordingLibrary
    let activeRecordingID: UUID?
    let onContinue: (UUID) -> Void
    let onExport: (UUID) -> Void

    var body: some View {
        NavigationStack {
            Group {
                if state.rows.isEmpty, !state.isLoading {
                    ContentUnavailableView {
                        Label("No recorded flights yet", systemImage: "clock.arrow.circlepath")
                    } description: {
                        Text("Load a Flight Plan in Cockpit. Recording starts automatically when movement and takeoff are detected.")
                    }
                    .accessibilityIdentifier("flights.empty")
                } else {
                    recordingsList
                }
            }
            .navigationTitle("Flights")
            .navigationSubtitle("Recorded executions of your Flight Plans")
            .navigationDestination(for: UUID.self) { id in
                FlightDetailLoaderView(
                    id: id,
                    library: library,
                    activeRecordingID: activeRecordingID,
                    onContinue: onContinue,
                    onExport: onExport,
                    onDeleted: { await loadRows() }
                )
            }
        }
        .task(id: activeRecordingID) {
            await loadRows()
        }
    }

    private var recordingsList: some View {
        List {
            let current = state.rows.filter(\.canContinue)
            if !current.isEmpty {
                Section("In Progress") {
                    ForEach(current) { row in
                        Button("Continue Flight", systemImage: "arrow.right") {
                            onContinue(row.id)
                        }
                        .accessibilityIdentifier("flights.continue.\(row.id.uuidString)")
                        FlightRecordingRow(summary: row)
                    }
                }
            }

            let recent = state.rows.filter { !$0.canContinue }
            if !recent.isEmpty {
                Section("Recent Flights") {
                    ForEach(recent) { row in
                        FlightRecordingRow(summary: row)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                if row.canDelete {
                                    Button("Delete", systemImage: "trash", role: .destructive) {
                                        Task { await delete(row.id) }
                                    }
                                }
                            }
                    }
                }
            }

            Text("On-device · Recordings stay here unless you export them.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .listRowBackground(Color.clear)
        }
        .listStyle(.insetGrouped)
        .accessibilityIdentifier("flights.list")
    }

    @MainActor
    private func loadRows() async {
        let requestID = UUID()
        state.beginLoading(requestID: requestID)
        let rows = await library.recordings(activeRecordingID: activeRecordingID)
        state.completeLoading(requestID: requestID, rows: rows)
    }

    @MainActor
    private func delete(_ id: UUID) async {
        do {
            try await library.delete(id: id)
            await loadRows()
        } catch {
            await loadRows()
        }
    }
}

private struct FlightRecordingRow: View {
    let summary: FlightRecordingSummary

    var body: some View {
        NavigationLink(value: summary.id) {
                HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(summary.flightPlanTitle)
                        .font(.headline)
                        .fixedSize(horizontal: false, vertical: true)
                    if let route = summary.route {
                        Text(route)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Text(metadata)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 4) {
                    Image(systemName: statusSymbol)
                    Text(statusText)
                }
                .font(.footnote.weight(.semibold))
                .foregroundStyle(statusColor)
                .fixedSize(horizontal: true, vertical: true)
                }
        }
        .disabled(summary.status == .unavailable)
        .buttonStyle(.plain)
        .frame(minHeight: 80)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityIdentifier("flights.row.\(summary.id.uuidString)")
    }

    private var metadata: String {
        var values = [summary.startedAt.formatted(date: .abbreviated, time: .shortened)]
        values.append(summary.duration.map(Self.durationText) ?? "Duration unavailable")
        values.append(gpsText)
        values.append(summary.approximateSizeBytes.map {
            ByteCountFormatter.string(fromByteCount: $0, countStyle: .file)
        } ?? "Size unavailable")
        return values.joined(separator: " · ")
    }

    private var gpsText: String {
        switch summary.gpsCoverage {
        case .available: "GPS available"
        case .partial: "Partial GPS"
        case .unavailable: "GPS unavailable"
        }
    }

    private var statusText: String {
        switch summary.status {
        case .inProgress: "In Progress"
        case .recoveryRequired: "Recovery Required"
        case .complete: "Complete"
        case .incomplete: "Incomplete"
        case .manuallyEnded: "Manually Ended"
        case .unavailable: "Unavailable"
        }
    }

    private var statusSymbol: String {
        switch summary.status {
        case .inProgress: "record.circle.fill"
        case .recoveryRequired: "arrow.clockwise.circle.fill"
        case .complete: "checkmark.circle.fill"
        case .incomplete, .manuallyEnded: "exclamationmark.circle.fill"
        case .unavailable: "questionmark.circle.fill"
        }
    }

    private var statusColor: Color {
        switch summary.status {
        case .inProgress, .recoveryRequired: .accentColor
        case .complete: .green
        case .incomplete, .manuallyEnded: .orange
        case .unavailable: .secondary
        }
    }

    private var accessibilityLabel: String {
        [summary.flightPlanTitle, summary.route, metadata, statusText]
            .compactMap { $0 }
            .joined(separator: ", ")
    }

    nonisolated private static func durationText(_ duration: Duration) -> String {
        let seconds = max(0, duration.components.seconds)
        let hours = seconds / 3_600
        let minutes = (seconds % 3_600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}
