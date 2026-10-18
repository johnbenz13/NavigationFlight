import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static let fplnav = UTType(filenameExtension: "fplnav") ?? .data
}

struct CockpitFeatureView: View {
    @State private var state = CockpitFeatureState()
    @State private var isImporterPresented = false
    @State private var isCockpitPresented = false
    @State private var presentedError: PresentedPlanError?
    private let loader = FPLNavFileLoader()
    private let adapter = CockpitPresentationAdapter()

    init() {
        let progressionPolicy: FlightSession.ProgressionPolicy
#if DEBUG
        progressionPolicy = ProcessInfo.processInfo.environment["NAVIGATION_FLIGHT_PROGRESSION_POLICY"] == "manual"
            ? .manualNextLeg
            : .automaticNextLeg
#else
        progressionPolicy = .automaticNextLeg
#endif
        var initialState = CockpitFeatureState(progressionPolicy: progressionPolicy)
#if DEBUG
        if let encoded = ProcessInfo.processInfo.environment["NAVIGATION_FLIGHT_UI_TEST_PLAN"],
           let data = Data(base64Encoded: encoded),
           let flight = try? FPLNavDecoder().decode(data) {
            try? initialState.accept(flight)
        }
#endif
        _state = State(initialValue: initialState)
    }

    var body: some View {
        content
            .fileImporter(
                isPresented: $isImporterPresented,
                allowedContentTypes: [.fplnav],
                allowsMultipleSelection: false
            ) { result in
                handleImport(result)
            } onCancellation: {
                state.cancelImport()
            }
            .alert(item: $presentedError) { error in
                Alert(
                    title: Text("Couldn’t Open Plan"),
                    message: Text(error.message),
                    dismissButton: .default(Text("OK"))
                )
            }
    }

    @ViewBuilder
    private var content: some View {
        if let flight = state.flight,
           let session = state.session,
           let presentation = try? adapter.makePresentation(
               flight: flight,
               legIndex: state.selectedLegIndex,
               mode: state.mode
           ) {
            if isCockpitPresented {
                if let mapPresentation = try? AviationMapPresentationFactory().makePresentation(
                    flight: flight,
                    session: session
                ) {
                    let nextLegPreparation = try? adapter.makeNextLegPreparation(
                        flight: flight,
                        session: session
                    )
                    let previousLegSummary = try? adapter.makePreviousLegSummary(
                        flight: flight,
                        session: session
                    )
                    let legStartChecklist = try? adapter.makeLegStartChecklist(
                        flight: flight,
                        session: session
                    )
                    CockpitView(
                        data: presentation,
                        mapPresentation: mapPresentation,
                        nextLegPreparation: nextLegPreparation,
                        previousLegSummary: previousLegSummary,
                        legStartChecklist: legStartChecklist,
                        checklistState: state.activeLegStartChecklist,
                        session: session,
                        onStartLeg: { try? state.startLeg(at: .now) },
                        onIdentifyDestination: { try? state.identifyDestination(at: .now) },
                        onWaypointReached: { try? state.reachCurrentWaypoint(at: .now) },
                        onIdentificationPointReached: { pointID, target in
                            try? state.reachIdentificationPoint(key: pointID, nextTarget: target, at: .now)
                        },
                        onOpenPilotETA: { state.openPilotETAEditor(target: $0) },
                        onAdjustPilotETA: { targetID, delta in
                            state.adjustPilotETA(targetKey: targetID, by: delta)
                        },
                        onCommitPilotETA: { state.commitPilotETA(targetKey: $0) },
                        onEditPilotETA: { state.beginEditingPilotETA(targetKey: $0) },
                        onShowPilotETACheck: { state.showPilotETACheck(targetKey: $0) },
                        onHidePilotETACheck: { state.hidePilotETACheck(targetKey: $0) },
                        onCollapseChecklist: { state.collapseLegStartChecklist() },
                        onReopenChecklist: { state.reopenLegStartChecklist() },
                        onNoteChecklist: { state.noteLegStartChecklist() },
                        onShowPlanInspection: { isCockpitPresented = false }
                    )
                }
            } else {
                PlanInspectionView(
                    data: presentation,
                    canSelectPreviousLeg: state.canSelectPreviousLeg,
                    canSelectNextLeg: state.canSelectNextLeg,
                    onOpenPlan: { isImporterPresented = true },
                    onOpenCockpit: { isCockpitPresented = true },
                    onSelectPreviousLeg: { state.selectPreviousLeg() },
                    onSelectNextLeg: { state.selectNextLeg() },
                    onSelectMode: { state.selectMode($0) }
                )
            }
        } else {
            ContentUnavailableView {
                Label("No Navigation Plan", systemImage: "map")
            } description: {
                Text("Open a prepared V7 .fplnav plan to inspect its saved execution data.")
            } actions: {
                Button {
                    isImporterPresented = true
                } label: {
                    Label("Open Plan", systemImage: "folder")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .accessibilityIdentifier("open-plan")
            }
        }
    }

    private func handleImport(_ result: Result<[URL], any Error>) {
        do {
            guard let url = try result.get().first else { return }
            let candidate = try loader.load(url)
            try state.accept(candidate)
            isCockpitPresented = false
        } catch let error as CockpitPlanError {
            presentedError = .init(message: error.localizedDescription)
        } catch {
            presentedError = .init(message: "The selected file couldn’t be opened. \(error.localizedDescription)")
        }
    }
}

private struct PresentedPlanError: Identifiable {
    let id = UUID()
    let message: String
}
