import SwiftUI
import UniformTypeIdentifiers

struct FlightPlansFeatureView: View {
    @Binding var state: FlightPlansFeatureState

    let library: FlightPlanLibrary
    let fileReader: FlightPlanFileReader
    let loadedFlightPlan: FlightPlan?
    let debugSeedData: [Data]
    let debugImportData: Data?
    let onIntent: (FlightPlansFeatureIntent) -> Void

    @State private var navigationPath: [UUID] = []
    @State private var scrollPosition: UUID?
    @State private var isFileImporterPresented = false

    var body: some View {
        NavigationStack(path: $navigationPath) {
            Group {
                if state.records.isEmpty {
                    FlightPlansEmptyView(isLoading: state.isLoading, onAdd: presentFileImporter)
                } else {
                    FlightPlansList(
                        records: state.records,
                        loadedFlightPlan: loadedFlightPlan,
                        scrollPosition: $scrollPosition,
                        onSelect: { id in
                            state.selectRecord(id: id)
                            navigationPath.append(id)
                        }
                    )
                }
            }
            .navigationTitle("Flight Plans")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("+ Add", action: presentFileImporter)
                        .buttonStyle(.borderedProminent)
                        .disabled(state.inFlightRequestID != nil)
                        .accessibilityLabel("Add Flight Plan")
                        .accessibilityIdentifier("add-flight-plan")
                }
            }
            .navigationDestination(for: UUID.self) { id in
                if let record = state.records.first(where: { $0.id == id }) {
                    FlightPlanInspectionView(
                        record: record,
                        loadedFlightPlan: loadedFlightPlan,
                        isActionDisabled: state.inFlightRequestID != nil,
                        onIntent: onIntent
                    )
                } else {
                    ContentUnavailableView("Flight Plan unavailable", systemImage: "folder.badge.questionmark")
                }
            }
            .fileImporter(
                isPresented: $isFileImporterPresented,
                allowedContentTypes: [Self.flightPlanType]
            ) { result in
                guard case .success(let url) = result else { return }
                Task { await importFlightPlan(from: url) }
            }
            .task {
                if state.records.isEmpty {
                    await installDebugSeedIfNeeded()
                    await refresh()
                    if let debugImportData {
                        await importFlightPlan(data: debugImportData)
                    }
                }
            }
            .alert(replacementTitle, isPresented: replacementPresented) {
                Button("Replace", role: replacementIsOlder ? .destructive : nil) {
                    guard let proposalID = state.pendingImport?.id else { return }
                    Task { await commit(proposalID: proposalID) }
                }
                Button("Cancel", role: .cancel) {
                    guard let proposalID = state.pendingImport?.id else { return }
                    state.cancelPendingImport(proposalID: proposalID)
                }
            } message: {
                Text(replacementMessage)
            }
            .alert(presentationTitle, isPresented: presentationPresented) {
                Button("Done") { state.dismissPresentation() }
            } message: {
                Text(presentationMessage)
            }
            .onChange(of: state.selectedRecordID) { _, selectedRecordID in
                if selectedRecordID == nil {
                    navigationPath.removeAll()
                }
            }
        }
    }

    private static let flightPlanType = UTType(filenameExtension: "fplnav") ?? .json

    private func presentFileImporter() {
        isFileImporterPresented = true
    }

    private func refresh() async {
        let requestID = UUID()
        state.beginLoading(requestID: requestID)
        do {
            let records = try await library.plans()
            state.completeLoading(requestID: requestID, records: records, error: nil)
        } catch let error as FlightPlanLibraryError {
            state.completeLoading(requestID: requestID, records: nil, error: error)
        } catch {
            state.completeLoading(requestID: requestID, records: nil, error: .storageFailure(id: nil))
        }
    }

    private func installDebugSeedIfNeeded() async {
#if DEBUG
        for (offset, data) in debugSeedData.enumerated() {
            guard let proposal = try? await library.prepareImport(
                data,
                importedAt: .now.addingTimeInterval(-Double(offset) * 86_400)
            ) else { continue }
            if case .sameRevision = proposal { continue }
            _ = try? await library.commit(proposal)
        }
#endif
    }

    private func importFlightPlan(from url: URL) async {
        let requestID = UUID()
        guard state.beginImport(requestID: requestID) else { return }
        do {
            let data = try await fileReader.data(from: url)
            await prepareImport(data: data, requestID: requestID)
        } catch is FlightPlanFileAccessError {
            state.failImport(requestID: requestID, failure: .unreadableFile)
        } catch let error as FlightPlanLibraryError {
            state.failImport(requestID: requestID, failure: failure(for: error))
        } catch {
            state.failImport(requestID: requestID, failure: .libraryUnavailable)
        }
    }

    private func importFlightPlan(data: Data) async {
        let requestID = UUID()
        guard state.beginImport(requestID: requestID) else { return }
        await prepareImport(data: data, requestID: requestID)
    }

    private func prepareImport(data: Data, requestID: UUID) async {
        do {
            let proposal = try await library.prepareImport(data, importedAt: .now)
            let proposalID = UUID()
            let decision = state.completeImportPreparation(
                requestID: requestID,
                proposalID: proposalID,
                proposal: proposal
            )
            if decision == .commit(proposalID: proposalID) {
                await commit(proposalID: proposalID)
            }
        } catch let error as FlightPlanLibraryError {
            state.failImport(requestID: requestID, failure: failure(for: error))
        } catch {
            state.failImport(requestID: requestID, failure: .libraryUnavailable)
        }
    }

    private func commit(proposalID: UUID) async {
        let requestID = UUID()
        guard let proposal = state.beginCommit(proposalID: proposalID, requestID: requestID) else { return }
        do {
            _ = try await library.commit(proposal)
            let records = try await library.plans()
            state.completeCommit(requestID: requestID, proposalID: proposalID, records: records)
        } catch let error as FlightPlanLibraryError {
            state.failImport(requestID: requestID, failure: failure(for: error))
        } catch {
            state.failImport(requestID: requestID, failure: .libraryUnavailable)
        }
    }

    private func failure(for error: FlightPlanLibraryError) -> FlightPlansFailure {
        switch error {
        case .invalidFlightPlan, .corruptRecord, .sameRevisionCannotBeCommitted:
            .invalidFlightPlan
        case .staleProposal:
            .staleProposal
        case .storageFailure:
            .storageFailure
        }
    }

    private var replacementPresented: Binding<Bool> {
        Binding(
            get: {
                guard let proposal = state.pendingImport?.proposal else { return false }
                switch proposal {
                case .replaceNewer, .replaceOlder: return true
                case .new, .sameRevision: return false
                }
            },
            set: { _ in }
        )
    }

    private var replacementIsOlder: Bool {
        guard case .replaceOlder = state.pendingImport?.proposal else { return false }
        return true
    }

    private var replacementTitle: String {
        replacementIsOlder ? "Replace with older revision?" : "Replace saved plan?"
    }

    private var replacementMessage: String {
        let title = state.pendingImport?.proposal.title ?? "this Flight Plan"
        if replacementIsOlder {
            return "The selected revision of \(title) is older than the saved revision. Cockpit will remain unchanged."
        }
        return "A newer revision of \(title) will replace the saved library copy. Cockpit will remain unchanged."
    }

    private var presentationPresented: Binding<Bool> {
        Binding(
            get: {
                guard let presentation = state.presentation else { return false }
                return presentation != .flightChangeFailure
            },
            set: { if !$0 { state.dismissPresentation() } }
        )
    }

    private var presentationTitle: String {
        switch state.presentation {
        case .alreadyImported: "Already imported"
        case .imported: "Flight Plan added"
        case .failure(.storageFailure): "Plan wasn’t saved"
        case .failure: "Couldn’t add this plan"
        case .flightChangeFailure: "Couldn’t load this Flight Plan"
        case nil: ""
        }
    }

    private var presentationMessage: String {
        switch state.presentation {
        case .alreadyImported(let title): "\(title) is already saved at this revision."
        case .imported(let title): "\(title) is saved locally and available in Flight Plans."
        case .failure(.unreadableFile): "The selected file could not be read. Existing Flight Plans and Cockpit are unchanged."
        case .failure(.invalidFlightPlan): "The file is malformed, unsupported, or missing required execution data."
        case .failure(.staleProposal): "The saved Flight Plan changed before replacement. Choose the file again."
        case .failure(.storageFailure): "The Flight Plan could not be saved. Existing data is unchanged."
        case .failure(.libraryUnavailable): "Flight Plans is temporarily unavailable. Existing data is unchanged."
        case .flightChangeFailure: "The current Flight and this inspection are unchanged."
        case nil: ""
        }
    }
}

private struct FlightPlanInspectionView: View {
    let record: LibraryFlightPlan
    let loadedFlightPlan: FlightPlan?
    let isActionDisabled: Bool
    let onIntent: (FlightPlansFeatureIntent) -> Void

    private var presentation: FlightPlanInspectionPresentation {
        FlightPlanInspectionPresentation(inspected: record, loadedFlightPlan: loadedFlightPlan)
    }

    var body: some View {
        List {
            Section("Route") {
                LabeledContent("Departure", value: record.flightPlan.waypoints.first?.name ?? "—")
                LabeledContent("Destination", value: record.flightPlan.waypoints.last?.name ?? "—")
            }

            Section("Flight Plan") {
                LabeledContent("Revision") {
                    Text(record.flightPlan.modifiedAt, format: .dateTime)
                }
                LabeledContent("Imported") {
                    Text(record.importedAt, format: .dateTime)
                }
            }

            Section {
                Button {
                    perform(presentation.primaryAction)
                } label: {
                    Text(presentation.primaryAction.label)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isActionDisabled)
                .accessibilityIdentifier(identifier(for: presentation.primaryAction))

                ForEach(presentation.secondaryActions, id: \.self) { action in
                    Button {
                        perform(action)
                    } label: {
                        Text(action.label)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .disabled(isActionDisabled)
                    .accessibilityIdentifier(identifier(for: action))
                }
            } footer: {
                Text("Loading or restarting creates a fresh Flight. Leg timing remains stopped until you start it in Cockpit.")
            }
        }
        .navigationTitle(record.flightPlan.title)
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("flight-plan-inspection")
    }

    private func perform(_ action: FlightPlanInspectionPresentation.Action) {
        switch action {
        case .loadInCockpit:
            onIntent(.loadInCockpit(record))
        case .returnToCockpit:
            onIntent(.returnToCockpit)
        case .loadUpdatedPlan:
            onIntent(.loadUpdatedPlan(record))
        case .restartFlight:
            onIntent(.restartFlight)
        }
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

private struct FlightPlansEmptyView: View {
    let isLoading: Bool
    let onAdd: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("No flight plans yet", systemImage: "folder")
        } description: {
            Text("Add a prepared .fplnav plan from Navigation Editor. Saved Flight Plans remain available offline.")
        } actions: {
            if isLoading {
                ProgressView()
            } else {
                Button("Add", systemImage: "plus", action: onAdd)
                    .buttonStyle(.borderedProminent)
            }
        }
        .accessibilityIdentifier("empty-flight-plans")
    }
}

private struct FlightPlansList: View {
    let records: [LibraryFlightPlan]
    let loadedFlightPlan: FlightPlan?
    @Binding var scrollPosition: UUID?
    let onSelect: (UUID) -> Void

    var body: some View {
        List {
            Section("Most recently imported") {
                ForEach(records) { record in
                    Button { onSelect(record.id) } label: {
                        FlightPlanRow(
                            title: record.flightPlan.title,
                            departure: record.flightPlan.waypoints.first?.name ?? "—",
                            destination: record.flightPlan.waypoints.last?.name ?? "—",
                            importedAt: record.importedAt,
                            isLoaded: record.isLoaded(in: loadedFlightPlan)
                        )
                    }
                    .buttonStyle(.plain)
                    .id(record.id)
                    .accessibilityLabel(rowAccessibilityLabel(for: record))
                    .accessibilityIdentifier("flight-plan-row-\(record.id.uuidString)")
                }
            }

            Text("Saved Flight Plans remain available offline after import.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .listRowBackground(Color.clear)
        }
        .listStyle(.insetGrouped)
        .scrollPosition(id: $scrollPosition)
    }

    private func rowAccessibilityLabel(for record: LibraryFlightPlan) -> String {
        let departure = record.flightPlan.waypoints.first?.name ?? "Unknown departure"
        let destination = record.flightPlan.waypoints.last?.name ?? "Unknown destination"
        let loaded = record.isLoaded(in: loadedFlightPlan) ? ", Loaded in Cockpit" : ""
        return "\(record.flightPlan.title), \(departure) to \(destination), imported \(record.importedAt.formatted(.relative(presentation: .named)))\(loaded)"
    }
}

private struct FlightPlanRow: View {
    let title: String
    let departure: String
    let destination: String
    let importedAt: Date
    let isLoaded: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            Text("\(departure) → \(destination)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline) {
                Text(importedAt, format: .relative(presentation: .named))
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
                Spacer()
                if isLoaded {
                    Label("Loaded in Cockpit", systemImage: "airplane")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tint)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(.tint.opacity(0.12), in: .rect(cornerRadius: 9))
                }
            }
        }
        .frame(minHeight: 88)
        .contentShape(.rect)
    }
}

private extension ImportProposal {
    var title: String {
        switch self {
        case .new(let prepared): prepared.flightPlan.title
        case .sameRevision(let existing): existing.flightPlan.title
        case .replaceNewer(let replacement), .replaceOlder(let replacement):
            replacement.candidate.flightPlan.title
        }
    }
}
