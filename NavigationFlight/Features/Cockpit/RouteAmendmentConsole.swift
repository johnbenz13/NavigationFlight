import SwiftUI

struct RouteAmendmentConsole: View {
    let draft: RouteAmendmentDraft
    let route: RouteAmendmentRoute
    let currentLegTiming: RouteAmendmentLegTiming?
    let compact: Bool
    var isPlotting = false
    let onIntent: (RouteAmendmentDraft.Intent) -> Void
    let saveStatus: CockpitFeatureState.RouteAmendmentSave.Status?
    var isReplacing = false
    var confirmationUnavailableWhileAmended = false
    let onConfirm: () -> Void
    var canConfirmReplacement = false
    let onKeepEditing: () -> Void
    let onPlaceAtMapCenter: () -> Void
    let onDiscard: () -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var correctionTarget: RouteAmendmentDraft.CorrectionPoint?
    @State private var isCorrectionActionsPresented = false

    private let actionColor = Color(red: 0, green: 0.40, blue: 0.75)

    @Binding var isPointPickerPresented: Bool

    var body: some View {
        VStack(spacing: 0) {
            RouteAmendmentCurrentLeg(timing: currentLegTiming, compact: compact)
                .padding(.top, compact ? 4 : 0)
                .fixedSize(horizontal: false, vertical: true)
            if let saveStatus {
                savePanel(saveStatus)
            } else {
                draftContent
            }
        }
        .padding(.horizontal, compact ? 16 : 20)
        .tint(.accentColor)
        .background(Color(.systemBackground))
        .sheet(isPresented: $isPointPickerPresented) {
            pointPicker
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    private var draftContent: some View {
        VStack(spacing: 0) {
            workspaceHeading
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.vertical, dynamicTypeSize.isAccessibilitySize ? 0 : 4)
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        if let message = draft.message, !draft.isInspecting {
                            Label(message, systemImage: "exclamationmark.circle")
                                .font(.subheadline)
                                .accessibilityIdentifier("amendment-feedback")
                        }
                        RouteAmendmentReview(draft: draft, route: route, compact: compact,
                                             isPlotting: isPlotting, isReplacing: isReplacing, onIntent: onIntent)
                            .allowsHitTesting(draft.legPanel == nil)
                        controls
                            .id("amendment-route-controls")
                            .allowsHitTesting(draft.legPanel == nil)
                        if confirmationUnavailableWhileAmended {
                            Text("You can keep editing this draft. Confirming another amendment on this revised route is unavailable.")
                                .font(.subheadline)
                                .foregroundStyle(PendingAmendmentPalette.secondary)
                        }
                        if isReplacing {
                            Text("Review the replacement leg values before confirming.")
                                .font(.subheadline)
                                .foregroundStyle(PendingAmendmentPalette.secondary)
                        }
                        if draft.step != .departure && draft.step != .drawing && draft.step != .review {
                            footer
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .scrollBounceBehavior(.basedOnSize)
                .accessibilityIdentifier("route-amendment-console")
                .onChange(of: draft.editor?.id) { _, id in
                    if let id { proxy.scrollTo(id, anchor: .center) }
                }
                .onChange(of: draft.reviewLegs(on: route).last?.id) { _, id in
                    if isPlotting, let id { proxy.scrollTo(id, anchor: .bottom) }
                }
                .onChange(of: draft.step) { _, step in
                    if case .crossing = step { proxy.scrollTo("amendment-route-controls", anchor: .top) }
                }
            }
            workspaceActions
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var workspaceHeading: some View {
        if dynamicTypeSize.isAccessibilitySize {
            HStack(spacing: 8) {
                Text("Amend")
                    .font(.caption2.weight(.semibold))
                    .accessibilityLabel("Amend route, \(draft.mode.title)")
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 0)
                drawingStatus.font(.caption2)
            }
            .frame(minHeight: 44)
        } else {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    workspaceTitle
                    Spacer(minLength: 0)
                    drawingStatus
                }
                VStack(alignment: .leading, spacing: 0) {
                    workspaceTitle
                    drawingStatus
                }
            }
            .frame(minHeight: 44)
        }
    }

    private var workspaceTitle: some View {
        HStack(spacing: 12) {
            Text(isReplacing ? "Review replacement" : compact ? "Amend · \(draft.mode.title)" : "Amend route")
                .font(compact ? .title3.bold() : .title2.bold())
                .accessibilityAddTraits(.isHeader)
            if !compact {
                Text("\(draft.mode.title) · \(legCountText)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(.secondarySystemBackground), in: .rect(cornerRadius: 7))
            }
        }
    }

    private var drawingStatus: some View {
        Text(draft.rejoin == nil ? "Drawing" : "Rejoined")
            .font(.subheadline.weight(.semibold))
            .accessibilityIdentifier("amendment-drawing-status")
    }

    @ViewBuilder
    private var workspaceActions: some View {
        if isReplacing {
            HStack(spacing: 8) {
                Button("Keep saved route") { onIntent(.discard) }
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("keep-saved-amendment")
                Button("Confirm replacement", action: onConfirm)
                    .buttonStyle(.borderedProminent)
                    .frame(minHeight: 44)
                    .disabled(!canConfirmReplacement || draft.legPanel != nil || draft.reviewLegs(on: route).contains { $0.values == nil })
                    .accessibilityIdentifier("confirm-amendment-replacement")
            }
            .padding(.bottom, 4)
        } else {
            preparationActions
        }
    }

    private var preparationActions: some View {
        let status = AmendmentLifecycleStatus.project(flight: nil, draft: draft, route: route)
        return VStack(alignment: .leading, spacing: 0) {
            if compact { readiness(status) }
            HStack(spacing: 8) {
                if dynamicTypeSize.isAccessibilitySize {
                    Menu("Actions") { workspaceEditingActions }
                        .frame(minWidth: 44, minHeight: 44)
                    Spacer(minLength: 0)
                } else {
                    workspaceEditingActions
                }
                if !compact {
                    Spacer(minLength: 0)
                    readiness(status)
                }
                Button(compact ? "Arm" : "Arm amendment") {}
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                    .fixedSize(horizontal: true, vertical: false)
                    .frame(minWidth: compact ? 80 : 154, minHeight: 44)
                    .disabled(true)
                    .accessibilityHint("Arming is not available yet")
                    .accessibilityIdentifier("arm-amendment")
            }
            .buttonStyle(.borderless)
            .frame(minHeight: 44)
            .controlSize(.regular)
        }
        .font(dynamicTypeSize.isAccessibilitySize ? .caption : .subheadline)
        .padding(.bottom, 4)
    }

    @ViewBuilder
    private var workspaceEditingActions: some View {
        Button("Undo") { onIntent(.undo) }
            .frame(minWidth: 44, minHeight: 44)
            .disabled(!draft.canUndo || draft.legPanel != nil)
            .accessibilityIdentifier("undo-amendment-plot")
        Button("Discard", role: .destructive, action: onDiscard)
            .frame(minWidth: 44, minHeight: 44)
            .accessibilityIdentifier("discard-amendment-draft")
    }

    private func readiness(_ status: AmendmentLifecycleStatus) -> some View {
        Text(status == .ready
             ? "\(dynamicTypeSize.isAccessibilitySize ? "Ready" : "Ready to arm") · \(legCountText)"
             : "\(draft.hasContent ? (dynamicTypeSize.isAccessibilitySize ? "Incomplete" : "Route incomplete") : "No amendment yet") · \(legCountText)")
            .font(.caption.weight(.semibold))
            .accessibilityIdentifier("amendment-readiness")
    }

    private var legCountText: String {
        let count = draft.reviewLegs(on: route).count
        return count == 1 ? "1 leg" : "\(count) legs"
    }

    private struct AmendmentActionAvailability: ViewModifier {
        @Environment(\.isEnabled) private var isEnabled

        func body(content: Content) -> some View {
            content.opacity(isEnabled ? 1 : 0.45)
        }
    }

    private func savePanel(_ status: CockpitFeatureState.RouteAmendmentSave.Status) -> some View {
        let saving = status == .saving
        let rejoin = draft.rejoin.map(route.name(for:)) ?? ""
        let count = draft.reviewLegs(on: route).count
        return VStack(alignment: .leading, spacing: 4) {
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(saving ? "Saving amendment" : "Amendment could not be saved")
                            .font(.title3.bold())
                            .accessibilityAddTraits(.isHeader)
                            .accessibilityIdentifier(saving ? "amendment-saving" : "amendment-save-failed")
                        Text(saving ? "The current route remains operational while the change is saved." : "The last confirmed route remains active.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Group {
                        if saving {
                            HStack(spacing: 8) {
                                ProgressView().controlSize(.small)
                                Text("Saving the selected departure and replacement legs…")
                            }
                        } else {
                            Text("Your changes are still in this draft. Retry to save the amendment.")
                                .foregroundStyle(.red)
                        }
                    }
                    .font(.subheadline)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(saving ? RouteAmendmentPanelStyle.neutral : Color.red.opacity(0.08),
                                in: .rect(cornerRadius: 12))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(saving ? "Confirmation" : "Draft route").font(.subheadline.weight(.semibold))
                        Text("\(count) replacement legs · rejoin at \(rejoin)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RouteAmendmentPanelStyle.neutral, in: .rect(cornerRadius: 12))
                }
            }
            .scrollBounceBehavior(.basedOnSize)
            if case .failed(let canEdit) = status {
                HStack {
                    Button(action: onKeepEditing) {
                        Text("Keep editing")
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 16)
                            .frame(minHeight: 52)
                            .background(actionColor.opacity(0.08), in: .rect(cornerRadius: 13))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(actionColor)
                    .disabled(!canEdit)
                    .accessibilityIdentifier("keep-editing-amendment")
                    Spacer(minLength: 12)
                    confirmationButton("Retry save", id: "retry-amendment-save")
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func confirmationButton(
        _ title: LocalizedStringKey, id: String, fullWidth: Bool = false, height: CGFloat = 52
    ) -> some View {
        Button(action: onConfirm) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 14)
                .frame(maxWidth: fullWidth ? .infinity : nil, minHeight: height)
                .foregroundStyle(.white)
                .background(actionColor, in: .rect(cornerRadius: 13))
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .modifier(AmendmentActionAvailability())
        .accessibilityIdentifier(id)
    }

    @ViewBuilder
    private var controls: some View {
        switch draft.step {
        case .departure:
            VStack(alignment: .leading, spacing: 4) {
                Text("Choose departure").font(.headline)
                Text("Choose a departure on the remaining original route. Each new leg appears here as you draw.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            if draft.departure != nil { button("Back to drawing", intent: .back) }
            if draft.departure == nil, draft.rejoin != nil {
                button("Choose a different rejoin too", intent: .clearRejoin)
            }
        case .drawing, .review:
            if draft.rejoin == nil {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Add another point or rejoin the route.")
                        .font(.subheadline.weight(.semibold))
                    Text("Select a proposed leg to enter values while drawing.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
            }
        case .move, .rejoin:
            if case .move = draft.step { Text("Tap the new location for this point").font(.subheadline) }
            else { Text("Choose a return point ahead of departure").font(.subheadline) }
            button("Back to drawing", intent: .back)
        case .confirmRejoin(let anchor):
            panel {
                Text(route.name(for: anchor)).font(.headline)
                Text(route.occurrence(for: anchor)).font(.caption).foregroundStyle(.secondary)
            }
            .accessibilityIdentifier("amendment-return-candidate")
        case .crossing(let options, let purpose):
            Text(purpose == .departure ? "Choose departure leg" : "Return to which leg?")
                .font(.headline)
            ForEach(options, id: \.self) { anchor in
                occurrenceOption(anchor)
            }
        case .staleDeparture:
            Text("Update departure").font(.headline)
            Label("Pilot-reported progress is past your departure. Choose a new departure on the remaining route.",
                  systemImage: "exclamationmark.triangle.fill")
                .font(.subheadline)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.orange.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
            panel {
                Text("Draft retained").font(.headline)
                Text("Your plotted points and rejoin are still in the draft.")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var pointPicker: some View {
        NavigationStack {
            List {
                Button("Use map center") {
                    isPointPickerPresented = false
                    onPlaceAtMapCenter()
                }
                if draft.acceptsPointCorrection {
                    Section("Correct route points") {
                        ForEach(draft.correctionPoints(on: route)) { point in
                            Button {
                                correctionTarget = point
                                isCorrectionActionsPresented = true
                            } label: {
                                correctionLabel(point.name)
                            }
                            .accessibilityIdentifier("amendment-correct-\(point.name)")
                        }
                    }
                }
                Section("Route waypoints") {
                    ForEach(draft.availableStops(on: route)) { stop in
                        Button {
                            if draft.step == .departure || draft.step == .rejoin {
                                sendPickerIntent(.chooseAnchor(stop.id))
                            } else {
                                sendPickerIntent(.plot(.init(position: stop.position, waypoint: stop)))
                            }
                        } label: {
                            Label("\(stop.name) · Leg \(stop.id.legIndex + 1)", systemImage: "mappin")
                        }
                        .accessibilityIdentifier("amendment-route-waypoint")
                    }
                }
            }
            .navigationTitle("Route waypoints")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { isPointPickerPresented = false }
                }
            }
        }
        .alert(correctionTarget?.name ?? "Point", isPresented: $isCorrectionActionsPresented,
               presenting: correctionTarget) { point in
            Button("Move") { sendPickerIntent(.movePoint(point.id)) }
            Button("Delete", role: .destructive) { sendPickerIntent(.removePoint(point.id)) }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func correctionLabel(_ name: String) -> some View {
        Text(name)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .contentShape(.rect)
    }

    private func sendPickerIntent(_ intent: RouteAmendmentDraft.Intent) {
        isPointPickerPresented = false
        onIntent(intent)
    }

    @ViewBuilder
    private var footer: some View {
        if case .confirmRejoin(let anchor) = draft.step {
            ViewThatFits(in: .horizontal) {
                HStack { rejoinActions(anchor) }
                VStack(alignment: .leading, spacing: 6) { rejoinActions(anchor) }
            }
        } else if case .crossing = draft.step {
            HStack {
                filledAction("Back to map", id: "back-from-amendment-crossing") { onIntent(.back) }
                Spacer(minLength: 0)
            }
        } else if draft.step == .staleDeparture {
            HStack {
                Spacer(minLength: 0)
                filledAction("Choose departure", id: "replace-amendment-departure", prominent: true) {
                    onIntent(.chooseDeparture)
                }
            }
        } else {
            HStack {
                discardButton
                Spacer(minLength: 0)
            }
        }
    }

    @ViewBuilder
    private func rejoinActions(_ anchor: RouteAmendmentAnchor) -> some View {
        filledAction("Back to drawing", id: "back-from-amendment-rejoin") { onIntent(.back) }
        Spacer(minLength: 0)
        filledAction("Return at \(route.name(for: anchor))", id: "confirm-amendment-rejoin", prominent: true) {
            onIntent(.confirmRejoin)
        }
    }

    private var undoAction: some View {
        filledAction("Undo", id: "undo-amendment-plot") { onIntent(.undo) }
            .accessibilityLabel("Undo last plot")
            .disabled(!draft.canUndo)
    }

    private var discardButton: some View {
        filledAction(draft.hasContent ? "Discard" : "Cancel", id: "discard-amendment-draft",
                     destructive: draft.hasContent, action: onDiscard)
            .accessibilityLabel(draft.hasContent ? "Discard draft" : "Cancel")
    }

    private func filledAction(
        _ title: String, id: String, prominent: Bool = false, destructive: Bool = false, action: @escaping () -> Void
    ) -> some View {
        let color = destructive ? Color.red : actionColor
        return Button(role: destructive ? .destructive : nil, action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, prominent ? 12 : 6)
                .frame(minHeight: 34)
                .foregroundStyle(prominent ? Color.white : color)
                .background(prominent ? actionColor : .clear, in: Capsule())
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(id)
        .modifier(RouteAmendmentDisabledOpacity())
    }

    private func occurrenceOption(_ anchor: RouteAmendmentAnchor) -> some View {
        Button { onIntent(.chooseAnchor(anchor)) } label: {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(route.occurrence(for: anchor)).font(.subheadline.weight(.semibold))
                    Text(route.name(for: anchor)).font(.caption).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                if !dynamicTypeSize.isAccessibilitySize {
                    Text("Use leg \(anchor.legIndex + 1)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(actionColor)
                        .padding(8)
                        .background(actionColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                }
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Use \(route.occurrence(for: anchor)), \(route.name(for: anchor))")
        .accessibilityIdentifier("amendment-leg-occurrence")
    }

    private func pointName(_ point: RouteAmendmentDraft.Point) -> String {
        if let name = point.name { return name }
        return "Point \((draft.points.firstIndex { $0.id == point.id } ?? 0) + 1)"
    }

    private func panel(@ViewBuilder _ content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 6, content: content)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    private func button(_ title: String, id: String = "", intent: RouteAmendmentDraft.Intent) -> some View {
        Button { onIntent(intent) } label: {
            Text(title)
                .frame(minHeight: 44)
                .contentShape(.rect)
        }
        .accessibilityIdentifier(id)
    }
}

nonisolated struct RouteAmendmentLegTiming {
    let startedAt: Date
    let destination: String
    let etaSeconds: Int
    let isRevised: Bool
    var origin = ""
    var legPosition = ""
    var plannedDurationSeconds: Int?
    var displayDate: Date?
    var legNumber: Int?

    func elapsedSeconds(at date: Date) -> Int {
        Int(max(0, date.timeIntervalSince(startedAt)))
    }

    func hasPassedETA(at date: Date) -> Bool {
        elapsedSeconds(at: date) > etaSeconds
    }
}

private struct RouteAmendmentCurrentLeg: View {
    let timing: RouteAmendmentLegTiming?
    let compact: Bool
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Group {
            if let timing {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    instruments(timing, now: timing.displayDate ?? context.date)
                }
            } else {
                Text("Current leg · not started")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)
            }
        }
        .padding(.horizontal, compact ? 10 : 16)
        .padding(.vertical, 4)
        .background(RouteAmendmentPanelStyle.quietTimingSurface, in: .rect(cornerRadius: 14))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("amendment-current-leg")
    }

    private func instruments(_ timing: RouteAmendmentLegTiming, now: Date) -> some View {
        let duration = timing.plannedDurationSeconds ?? timing.etaSeconds
        return Group {
            if dynamicTypeSize.isAccessibilitySize {
                ScrollView(.horizontal) {
                    HStack(spacing: 20) {
                        timer(timing, now: now)
                        metric("Leg time · planned", value: AviationMapSymbology.formatDuration(duration),
                               identifier: "amendment-leg-planned")
                        if timing.elapsedSeconds(at: now) > duration { overPlanned }
                        identity(timing)
                    }
                    .fixedSize(horizontal: true, vertical: false)
                }
            } else if compact {
                VStack(alignment: .leading, spacing: 2) {
                    identity(timing)
                    HStack(alignment: .top, spacing: 16) {
                        timer(timing, now: now)
                        planned(duration, now: now, timing: timing)
                    }
                }
            } else {
                HStack(spacing: 20) {
                    identity(timing)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Divider().frame(height: 40)
                    timer(timing, now: now).frame(width: 128)
                    Divider().frame(height: 40)
                    planned(duration, now: now, timing: timing).frame(width: 240)
                }
                .frame(minHeight: 52)
            }
        }
    }

    private func identity(_ timing: RouteAmendmentLegTiming) -> some View {
        VStack(alignment: .leading, spacing: compact ? 0 : 4) {
            if !compact {
                Text("CURRENT LEG · \(timing.legPosition.uppercased())")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text("\(compact ? timing.legNumber.map { "LEG \($0) · " } ?? "" : "")\(RouteAmendmentRoute.legName(from: timing.origin, to: timing.destination))")
                .font(compact ? .caption.weight(.semibold) : .headline)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func timer(_ timing: RouteAmendmentLegTiming, now: Date) -> some View {
        metric("Timer", value: AviationMapSymbology.formatDuration(timing.elapsedSeconds(at: now)),
               identifier: "amendment-leg-elapsed")
    }

    private func planned(_ seconds: Int, now: Date, timing: RouteAmendmentLegTiming) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Leg time · planned").font(.caption).foregroundStyle(.secondary)
            HStack(spacing: 10) {
                Text(AviationMapSymbology.formatDuration(seconds))
                    .font(compact ? .title2.weight(.semibold).monospacedDigit() : .title.weight(.semibold).monospacedDigit())
                    .accessibilityIdentifier("amendment-leg-planned")
                if !compact, timing.elapsedSeconds(at: now) > seconds { overPlanned }
            }
            if compact, timing.elapsedSeconds(at: now) > seconds { overPlanned }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func metric(_ title: String, value: String, identifier: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value)
                .font(compact ? .title2.weight(.semibold).monospacedDigit() : .title.weight(.semibold).monospacedDigit())
                .accessibilityIdentifier(identifier)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var overPlanned: some View {
        Text("Over planned")
            .font(.caption.weight(.semibold))
            .foregroundStyle(RouteAmendmentPanelStyle.overPlannedInk)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.orange.opacity(0.12), in: .rect(cornerRadius: 7))
    }
}

private struct RouteAmendmentDisabledOpacity: ViewModifier {
    @Environment(\.isEnabled) private var isEnabled

    func body(content: Content) -> some View {
        content.opacity(isEnabled ? 1 : 0.48)
    }
}

struct RouteAmendmentLegend: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                ScrollView(.horizontal) {
                    HStack(spacing: 16) { retained; bypassed; proposed; marks }
                        .fixedSize(horizontal: true, vertical: false)
                }
                .fixedSize(horizontal: false, vertical: true)
            } else {
                ViewThatFits(in: .horizontal) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 10) { retained; bypassed }
                        HStack(spacing: 10) { proposed; marks }
                    }
                    VStack(alignment: .leading, spacing: 4) { retained; bypassed; proposed; marks }
                }
            }
        }
        .font(.caption.weight(.semibold))
        .padding(9)
        .background(Color(uiColor: .systemBackground), in: .rect(cornerRadius: 9))
        .accessibilityElement(children: .combine)
        .allowsHitTesting(dynamicTypeSize.isAccessibilitySize)
    }

    private var retained: some View {
        entry("Original retained", color: Color(RouteAmendmentMapOverlay.retainedColor))
    }

    private var bypassed: some View {
        entry("Original bypassed", color: Color(RouteAmendmentMapOverlay.bypassedColor), dashed: true)
    }

    private var proposed: some View {
        entry("Proposed", color: Color(RouteAmendmentMapOverlay.proposedColor))
    }

    private var marks: some View {
        Label("Original minute marks", systemImage: "line.diagonal")
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func entry(_ name: String, color: Color, dashed: Bool = false) -> some View {
        HStack(spacing: 5) {
            Path { path in
                path.move(to: CGPoint(x: 0, y: 4))
                path.addLine(to: CGPoint(x: 19, y: 4))
            }
            .stroke(color, style: StrokeStyle(lineWidth: 3, dash: dashed ? [4, 3] : []))
            .frame(width: 19, height: 8)
            Text(name)
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}
