import SwiftUI

struct FlightsFeatureView: View {
    @Binding var state: FlightsFeatureState
    let library: FlightRecordingLibrary
    let activeRecordingID: UUID?
    let onContinue: (UUID) -> Void
    var exporter = GPXExporter()

    @State private var isDeleting = false

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
                    exporter: exporter,
                    flightsState: $state,
                    onRequestDelete: { state.requestDeletion(of: id) }
                )
            }
        }
        .task(id: activeRecordingID) {
            await loadRows()
        }
        .alert(
            deletionConfirmationTitle,
            isPresented: deletionConfirmationPresented
        ) {
            Button("Delete", role: .destructive) {
                guard let id = state.pendingDeletionID, !isDeleting else { return }
                isDeleting = true
                Task { await delete(id) }
            }
            Button("Cancel", role: .cancel) {
                state.cancelDeletion()
            }
        } message: {
            Text("This permanently removes the GPS track and navigation event history from this device.")
        }
        .alert(deletionFailureTitle, isPresented: deletionFailurePresented) {
            Button("Retry") {
                state.retryFailedDeletion()
            }
            Button("Cancel", role: .cancel) {
                state.dismissDeletionFailure()
            }
        } message: {
            Text("The recording and all of its files remain on this device. Try deleting it again.")
        }
    }

    private var recordingsList: some View {
        ViewThatFits(in: .horizontal) {
            wideRecordingsList
                .frame(minWidth: 900)
            compactRecordingsList
        }
    }

    private var compactRecordingsList: some View {
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
                                        state.requestDeletion(of: row.id)
                                    }
                                    .accessibilityIdentifier("flights.delete.\(row.id.uuidString)")
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

    private var wideRecordingsList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                let current = state.rows.filter(\.canContinue)
                if !current.isEmpty {
                    Text("In Progress")
                        .font(.headline)
                        .accessibilityAddTraits(.isHeader)
                    ForEach(current) { row in
                        VStack(alignment: .leading, spacing: 10) {
                            FlightRecordingRow(summary: row)
                            Button("Continue Flight", systemImage: "arrow.right") {
                                onContinue(row.id)
                            }
                            .buttonStyle(.borderedProminent)
                            .accessibilityIdentifier("flights.continue.\(row.id.uuidString)")
                        }
                    }
                }

                let recent = state.rows.filter { !$0.canContinue }
                if !recent.isEmpty {
                    Text("Recent Flights")
                        .font(.title3.bold())
                        .accessibilityAddTraits(.isHeader)
                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(), spacing: 20),
                            GridItem(.flexible(), spacing: 20)
                        ],
                        alignment: .leading,
                        spacing: 16
                    ) {
                        ForEach(recent) { row in
                            FlightRecordingRow(summary: row)
                                .padding(.horizontal, 16)
                                .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 16))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color(.separator), lineWidth: 0.5)
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    if row.canDelete {
                                        Button("Delete", systemImage: "trash", role: .destructive) {
                                            state.requestDeletion(of: row.id)
                                        }
                                        .accessibilityIdentifier("flights.delete.\(row.id.uuidString)")
                                    }
                                }
                        }
                    }
                }

                Text("On-device · Recordings stay here unless you export them.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 48)
            .padding(.vertical, 24)
        }
        .background(Color(.secondarySystemBackground))
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
        guard isDeleting, state.pendingDeletionID == id else { return }
        do {
            try await library.delete(id: id)
            state.completeDeletion(id: id)
            isDeleting = false
        } catch {
            state.failDeletion(id: id)
            await Task.yield()
            isDeleting = false
        }
    }

    private var deletionConfirmationPresented: Binding<Bool> {
        Binding(
            get: { state.pendingDeletionID != nil && !isDeleting },
            set: { isPresented in
                if !isPresented, !isDeleting {
                    state.cancelDeletion()
                }
            }
        )
    }

    private var deletionFailurePresented: Binding<Bool> {
        Binding(
            get: { state.deletionFailureID != nil },
            set: { if !$0 { state.dismissDeletionFailure() } }
        )
    }

    private var deletionConfirmationTitle: String {
        guard let id = state.pendingDeletionID,
              let row = state.rows.first(where: { $0.id == id }) else {
            return "Delete this Flight?"
        }
        return "Delete \(row.flightPlanTitle)?"
    }

    private var deletionFailureTitle: String {
        guard let id = state.deletionFailureID,
              let row = state.rows.first(where: { $0.id == id }) else {
            return "Couldn’t delete this Flight"
        }
        return "Couldn’t delete \(row.flightPlanTitle)"
    }
}

private struct FlightRecordingRow: View {
    let summary: FlightRecordingSummary

    var body: some View {
        NavigationLink(value: summary.id) {
            FlightRecordingRowContent(summary: summary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityIdentifier("flights.row.\(summary.id.uuidString)")
    }

    private var accessibilityLabel: String {
        let route = summary.route.map { ", \($0)" } ?? ""
        return "\(summary.flightPlanTitle)\(route), \(statusText), \(gpsText), \(metadata)"
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

    private var gpsText: String {
        switch summary.gpsCoverage {
        case .available: "GPS available"
        case .partial: "Partial GPS"
        case .unavailable: "GPS unavailable"
        }
    }

    private var metadata: String {
        let date = summary.startedAt.formatted(date: .abbreviated, time: .shortened)
        guard let duration = summary.duration else { return date }
        let minutes = max(0, duration.components.seconds) / 60
        return "\(date) · \(minutes)m"
    }
}

private struct FlightRecordingRowContent: View {
    let summary: FlightRecordingSummary

    var body: some View {
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
        .buttonStyle(.plain)
        .frame(minHeight: 80)
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
