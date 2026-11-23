import SwiftUI

struct RouteAmendmentConsole: View {
    let draft: RouteAmendmentDraft
    let route: RouteAmendmentRoute
    let currentLegTiming: RouteAmendmentLegTiming?
    let compact: Bool
    let inSideRail: Bool
    let onIntent: (RouteAmendmentDraft.Intent) -> Void
    let saveStatus: CockpitFeatureState.RouteAmendmentSave.Status?
    var isReplacing = false
    var confirmationUnavailableWhileAmended = false
    let onConfirm: () -> Void
    let onStartNow: () -> Void
    let canStartNow: Bool
    let canConfirmForLater: Bool
    let onKeepEditing: () -> Void
    let onPlaceAtMapCenter: () -> Void
    let onDiscard: () -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private let actionColor = Color(red: 0, green: 0.40, blue: 0.75)

    @State private var isPointPickerPresented = false

    var body: some View {
        VStack(spacing: 0) {
            if !isReplacing || draft.step != .review || saveStatus != nil {
                RouteAmendmentCurrentLeg(timing: currentLegTiming, compact: compact)
                    .padding(.top, compact ? 8 : 12)
            }
            if let saveStatus {
                savePanel(saveStatus)
            } else {
                draftContent
            }
        }
        .padding(.horizontal, compact ? 12 : 20)
        .tint(actionColor)
        .background(Color(.systemBackground))
        .sheet(isPresented: $isPointPickerPresented) {
            pointPicker
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    private var draftContent: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    draftHeading
                    if let message = draft.message, !draft.isInspecting {
                        Label(message, systemImage: "exclamationmark.circle")
                            .font(.subheadline)
                            .accessibilityIdentifier("amendment-feedback")
                    }
                    controls
                        .allowsHitTesting(draft.legPanel == nil)
                    if inSideRail, draft.step == .review {
                        if isReplacing {
                            reviewFooter.padding(.top, 14)
                        } else {
                            reviewConfirmationButtons.padding(.top, 12)
                        }
                    }
                    if showsFooter, actionsFollowEditor { footer }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollBounceBehavior(.basedOnSize)
            .accessibilityIdentifier("route-amendment-console")
            if draft.step == .review, !(inSideRail && isReplacing) {
                reviewFooter
            } else if showsFooter, !actionsFollowEditor {
                footer
                    .allowsHitTesting(draft.legPanel == nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 4)
            }
        }
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

    private var draftHeading: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 10) {
                draftTitle
                Spacer(minLength: 0)
                headingActions
            }
            VStack(alignment: .leading, spacing: 2) {
                draftTitle
                headingActions
            }
        }
        .frame(minHeight: 44)
        .padding(.vertical, isReplacing && draft.step == .review ? 12 : 0)
        .allowsHitTesting(draft.legPanel == nil)
    }

    @ViewBuilder
    private var headingActions: some View {
        if draft.step == .review {
            if isReplacing, let timing = currentLegTiming {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let elapsed = AviationMapSymbology.formatDuration(timing.elapsedSeconds(at: context.date))
                    Text("\(draft.mode.title) · Active leg · \(elapsed)")
                        .font(.subheadline)
                        .foregroundStyle(PendingAmendmentPalette.secondary)
                }
            } else {
                reviewLegCount
                lightweightAction("Choose leg", id: "choose-amendment-leg") { onIntent(.chooseLeg) }
            }
        } else if draft.acceptsMapInput || draft.isInspecting {
            pointInput
            lightweightAction("Inspect leg", id: "inspect-amendment-leg") { onIntent(.inspectOriginal) }
        }
    }

    private var draftTitle: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(isReplacing && draft.step == .review ? .title2.bold() : .title3.weight(.semibold))
                .accessibilityAddTraits(.isHeader)
            if isReplacing && draft.step == .review {
                Text("The saved amendment remains pending until this replacement is confirmed.")
                    .font(.subheadline)
                    .foregroundStyle(PendingAmendmentPalette.secondary)
            } else if draft.step != .drawing && draft.step != .review {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private var actionsFollowEditor: Bool {
        switch draft.step {
        case .confirmRejoin, .crossing: true
        default: inSideRail || dynamicTypeSize.isAccessibilitySize
        }
    }

    private var showsFooter: Bool {
        switch draft.step {
        case .departure, .drawing, .crossing, .confirmRejoin, .staleDeparture: true
        default: false
        }
    }

    private var title: String {
        switch draft.step {
        case .departure, .drawing, .move: "Amend route"
        case .rejoin, .confirmRejoin: "Pick a return point"
        case .crossing(_, let purpose): purpose == .departure ? "Choose departure leg" : "Choose return leg"
        case .staleDeparture: "Update departure"
        case .review: isReplacing ? "Review replacement" : "Review legs"
        }
    }

    private var subtitle: String {
        switch draft.step {
        case .departure: "Choose departure"
        case .drawing: ""
        case .move: "Tap the new location for this point"
        case .rejoin: "Tap a waypoint or a point along the route ahead."
        case .confirmRejoin: "Confirm where the amendment returns to the route."
        case .crossing: "More than one leg passes through this location."
        case .staleDeparture: "Your draft is still available."
        case .review: ""
        }
    }

    @ViewBuilder
    private var controls: some View {
        switch draft.step {
        case .departure:
            panel {
                Text("Tap a waypoint or a point along the remaining route.")
            }
            if draft.departure != nil { button("Back to drawing", intent: .back) }
            if draft.departure == nil, draft.rejoin != nil {
                button("Choose a different rejoin too", intent: .clearRejoin)
            }
        case .drawing:
            routeSequence
            if let point = draft.points.first(where: { $0.id == draft.selectedPointID }) {
                selectedPointRow(point)
            }
        case .move, .rejoin:
            routeSequence
            button("Back to drawing", intent: .back)
        case .confirmRejoin(let anchor):
            panel {
                Text(route.name(for: anchor)).font(.headline)
                Text(route.occurrence(for: anchor)).font(.caption).foregroundStyle(.secondary)
            }
            .accessibilityIdentifier("amendment-return-candidate")
        case .crossing(let options, _):
            ForEach(options, id: \.self) { anchor in
                occurrenceOption(anchor)
            }
        case .staleDeparture:
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
        case .review:
            RouteAmendmentReview(draft: draft, route: route, compact: compact, isReplacing: isReplacing, onIntent: onIntent)
                .allowsHitTesting(draft.legPanel == nil)
            if confirmationUnavailableWhileAmended {
                Text("You can keep editing this draft. Confirming another amendment while flying replacement legs is unavailable.")
                    .font(.subheadline)
                    .foregroundStyle(PendingAmendmentPalette.secondary)
            }
            if isReplacing {
                Divider().padding(.vertical, 12)
                Text("Review the replacement leg values before confirming.")
                    .font(.subheadline)
                    .foregroundStyle(PendingAmendmentPalette.secondary)
            }

        }
    }

    private enum RouteItemID: Hashable {
        case departure, point(UUID), rejoin
    }

    private struct RouteItem: Identifiable {
        let id: RouteItemID
        let name: String

        var role: String {
            switch id {
            case .departure: "Departure"
            case .point: "Via"
            case .rejoin: "Return"
            }
        }

        var accessibilityID: String {
            switch id {
            case .departure: "amendment-departure-point"
            case .point: "amendment-draft-point"
            case .rejoin: "amendment-return-point"
            }
        }

        var intent: RouteAmendmentDraft.Intent {
            switch id {
            case .departure: .chooseDeparture
            case .point(let id): .selectPoint(id)
            case .rejoin: .chooseRejoin
            }
        }
    }

    private var reviewFooter: some View {
        VStack(spacing: 1) {
            if isReplacing {
                let layout = compact || dynamicTypeSize.isAccessibilitySize
                    ? AnyLayout(VStackLayout(spacing: 8)) : AnyLayout(HStackLayout(spacing: 12))
                layout {
                    Button { onIntent(.discard) } label: {
                        Text("Keep saved route")
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 18)
                            .frame(maxWidth: compact ? .infinity : nil, minHeight: 54)
                            .foregroundStyle(actionColor)
                            .background(actionColor.opacity(0.08), in: .rect(cornerRadius: 13))
                            .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("keep-saved-amendment")
                    confirmForLaterButton
                }
            } else if compact || dynamicTypeSize.isAccessibilitySize {
                HStack {
                    backToDrawingButton
                    Spacer()
                    reviewPauseButton
                }
                if !inSideRail { reviewConfirmationButtons }
            } else {
                HStack(spacing: 12) {
                    backToDrawingButton
                    Spacer(minLength: 4)
                    startNowButton
                    confirmForLaterButton.frame(maxWidth: 556)
                    reviewPauseButton
                }
            }
        }
        .padding(.bottom, 4)
    }

    private var backToDrawingButton: some View {
        lightweightAction("Back to drawing", id: "back-to-amendment-drawing", symbol: "chevron.backward") {
            onIntent(.back)
        }
        .allowsHitTesting(draft.legPanel == nil)
    }

    private var reviewPauseButton: some View {
        Button { onIntent(.pause) } label: {
            Image(systemName: "pause")
                .font(.subheadline.weight(.semibold))
                .frame(width: 44, height: 44)
                .contentShape(.rect)
                .background(RouteAmendmentPanelStyle.neutral, in: .rect(cornerRadius: 12))
                .foregroundStyle(.primary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Pause route amendment draft")
        .accessibilityIdentifier("pause-amendment-review")
    }

    private var reviewConfirmationButtons: some View {
        VStack(spacing: 8) {
            confirmForLaterButton
            startNowButton
        }
    }

    @ViewBuilder
    private var startNowButton: some View {
        if canStartNow {
            Button(action: onStartNow) {
                Text("Start now")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(actionColor)
                    .padding(.horizontal, 14)
                    .frame(maxWidth: compact ? .infinity : nil, minHeight: 52)
                    .background(actionColor.opacity(0.08), in: .rect(cornerRadius: 13))
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .modifier(AmendmentActionAvailability())
            .disabled(draft.legPanel != nil || draft.reviewLegs(on: route).contains { $0.values == nil })
            .accessibilityHint("Confirms departure at the selected point and starts timing the first amendment leg")
            .accessibilityIdentifier("start-amendment-now")
        }
    }

    private var confirmForLaterButton: some View {
        confirmationButton(
            isReplacing ? "Confirm replacement" : "Confirm for later",
            id: isReplacing ? "confirm-amendment-replacement" : "confirm-amendment-for-later",
            fullWidth: true, height: 54
        )
            .disabled(!canConfirmForLater || draft.legPanel != nil || draft.reviewLegs(on: route).contains { $0.values == nil })
    }

    private func lightweightAction(
        _ title: LocalizedStringKey, id: String, symbol: String? = nil, perform: @escaping () -> Void
    ) -> some View {
        Button(action: perform) {
            HStack(spacing: 4) {
                if let symbol { Image(systemName: symbol).font(.caption.weight(.semibold)) }
                Text(title).font(.subheadline)
            }
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(.rect)
            .foregroundStyle(RouteAmendmentPanelStyle.action)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(id)
    }

    private var reviewLegCount: some View {
        let count = draft.points.count + 1
        let legs = count == 1 ? "1 leg" : "\(count) legs"
        return Text("\(draft.mode.title) · \(legs)")
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    private var routeAccent: Color { Color(RouteAmendmentMapOverlay.proposedColor) }

    private var routeItems: [RouteItem] {
        var items: [RouteItem] = []
        if let departure = draft.departure {
            items.append(.init(id: .departure, name: route.name(for: departure)))
        }
        items += draft.points.map { .init(id: .point($0.id), name: pointName($0)) }
        if let rejoin = draft.rejoin {
            items.append(.init(id: .rejoin, name: route.name(for: rejoin)))
        }
        return items
    }

    private var routeSequence: some View {
        let items = routeItems
        return ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                HStack(spacing: compact ? 4 : 8) {
                    ForEach(items) { item in
                        if item.id != items.first?.id {
                            Image(systemName: "chevron.forward")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .accessibilityHidden(true)
                        }
                        routeChip(item)
                            .id(item.id)
                    }
                }
                .padding(.vertical, 1)
            }
            .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
            .accessibilityIdentifier("amendment-route-sequence")
            .onChange(of: draft.selectedPointID, initial: true) { _, selected in
                if let selected { proxy.scrollTo(RouteItemID.point(selected)) }
            }
        }
    }

    @ViewBuilder
    private func routeChip(_ item: RouteItem) -> some View {
        let selected = draft.selectedPointID.map { item.id == .point($0) } == true
        let label = VStack(alignment: .leading, spacing: 1) {
            Text(item.name)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(selected ? routeAccent : .primary)
            Text(item.role)
                .font(.caption2)
                .foregroundStyle(selected ? routeAccent : .secondary)
        }
        .padding(.horizontal, compact ? 7 : 10)
        .padding(.vertical, 3)
        .frame(minHeight: 44, alignment: .leading)
        .fixedSize(horizontal: true, vertical: false)
        .background(selected ? routeAccent.opacity(0.12) : Color(.secondarySystemBackground),
                    in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            if selected { RoundedRectangle(cornerRadius: 8).strokeBorder(routeAccent, lineWidth: 1.5) }
        }
        .contentShape(.rect)

        if draft.step == .drawing {
            Button { onIntent(item.intent) } label: { label }
                .buttonStyle(.plain)
                .accessibilityLabel("\(item.name), \(item.role)")
                .accessibilityAddTraits(selected ? .isSelected : [])
                .accessibilityIdentifier(item.accessibilityID)
        } else {
            label
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier(item.accessibilityID)
        }
    }

    private var pointInput: some View {
        Button { isPointPickerPresented = true } label: {
            Text("Pick a point")
                .font(.subheadline.weight(.semibold))
                .frame(minHeight: 44)
                .contentShape(.rect)
        }
        .accessibilityHint("Choose a route waypoint or use the center of the map")
        .accessibilityIdentifier("pick-amendment-point")
    }

    private var pointPicker: some View {
        NavigationStack {
            List {
                Button("Use map center") {
                    isPointPickerPresented = false
                    onPlaceAtMapCenter()
                }
                if draft.step == .drawing {
                    Button("Change departure") { sendPickerIntent(.chooseDeparture) }
                    if draft.rejoin != nil {
                        Button("Change return point") { sendPickerIntent(.chooseRejoin) }
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
            .navigationTitle("Pick a point")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { isPointPickerPresented = false }
                }
            }
        }
    }

    private func sendPickerIntent(_ intent: RouteAmendmentDraft.Intent) {
        isPointPickerPresented = false
        onIntent(intent)
    }

    @ViewBuilder
    private var footer: some View {
        if draft.step == .drawing {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 2) {
                    undoAction
                    discardButton
                    Spacer(minLength: 4)
                    drawingPrimaryAction
                }
                VStack(alignment: .leading, spacing: 4) {
                    drawingPrimaryAction
                    HStack(spacing: 4) { undoAction; discardButton }
                }
            }
        } else if case .confirmRejoin(let anchor) = draft.step {
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

    @ViewBuilder
    private var drawingPrimaryAction: some View {
        if canFinishHere, let last = draft.points.last {
            let title = draft.selectedPointID == last.id ? "Finish here" : "Finish at \(pointName(last))"
            filledAction(title, id: "finish-amendment-here", prominent: true) { onIntent(.finishHere) }
        } else if draft.rejoin == nil {
            filledAction("Pick a return point", id: "choose-amendment-rejoin", prominent: true) { onIntent(.chooseRejoin) }
        } else {
            filledAction("Review legs", id: "review-amendment-legs", prominent: true) { onIntent(.review) }
                .disabled(!draft.canReview)
        }
    }

    private var canFinishHere: Bool { !draft.finishCandidates(on: route).isEmpty }

    private func selectedPointRow(_ point: RouteAmendmentDraft.Point) -> some View {
        let name = pointName(point)
        // Keep right-to-left waypoint names in place within the surrounding sentence.
        let displayName = "\u{2068}\(name)\u{2069}"
        let description: String
        if draft.rejoin == nil, point.id == draft.points.last?.id, canFinishHere {
            description = "\(displayName) is on the original route"
        } else if draft.rejoin == nil, point.id == draft.points.last?.id, point.routeCandidates.isEmpty {
            description = "\(displayName) is off the route"
        } else {
            description = "Editing \(name)"
        }
        let status = Text(description)
            .font(.caption)
            .foregroundStyle(.secondary)
            .accessibilityLabel(name)
            .accessibilityIdentifier("selected-amendment-point")
        return ViewThatFits(in: .horizontal) {
            HStack(spacing: compact ? 1 : 6) {
                status
                Spacer(minLength: 4)
                pointActions(point.id)
            }
            VStack(alignment: .leading, spacing: 4) {
                status
                HStack(spacing: 4) { pointActions(point.id) }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func pointActions(_ id: UUID) -> some View {
        filledAction("Move", id: "move-amendment-point") { onIntent(.movePoint(id)) }
            .accessibilityLabel("Move point")
        filledAction("Remove", id: "remove-amendment-point") { onIntent(.removePoint(id)) }
            .accessibilityLabel("Remove point")
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

    private let secondaryInk = Color(red: 0.75, green: 0.82, blue: 0.89)
    private let dueInk = Color(red: 1, green: 0.80, blue: 0.51)

    var body: some View {
        Group {
            if let timing {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    activeInstruments(timing, now: context.date)
                }
            } else {
                VStack(alignment: .leading, spacing: 5) {
                    currentLegLabel
                    Text("Leg not started")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity, minHeight: compact ? 61 : 60, alignment: .leading)
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(Color(red: 0.06, green: 0.14, blue: 0.21), in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("amendment-current-leg")
    }

    private func activeInstruments(_ timing: RouteAmendmentLegTiming, now: Date) -> some View {
        let elapsed = AviationMapSymbology.formatDuration(timing.elapsedSeconds(at: now))
        let eta = AviationMapSymbology.formatDuration(timing.etaSeconds)
        let passed = timing.hasPassedETA(at: now)
        return Group {
            if compact {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        currentLegLabel
                        Spacer(minLength: 4)
                        destination(timing.destination)
                    }
                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .top, spacing: 10) {
                            elapsedMetric(elapsed)
                            timingDivider
                            etaMetric(eta, revised: timing.isRevised, passed: passed)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            elapsedMetric(elapsed)
                            etaMetric(eta, revised: timing.isRevised, passed: passed)
                        }
                    }
                }
            } else {
                HStack(alignment: .center, spacing: 16) {
                    VStack(alignment: .leading, spacing: 3) {
                        currentLegLabel
                        destination(timing.destination)
                    }
                    .frame(width: 145, alignment: .leading)
                    timingDivider
                    elapsedMetric(elapsed)
                    timingDivider
                    etaMetric(eta, revised: timing.isRevised, passed: passed)
                }
                .frame(minHeight: 60)
            }
        }
    }

    private var currentLegLabel: some View {
        Text("Current leg")
            .font(.subheadline.weight(.semibold))
            .accessibilityAddTraits(.isHeader)
    }

    private func destination(_ name: String) -> some View {
        Text("To \(name)")
            .font(.caption)
            .foregroundStyle(secondaryInk)
            .lineLimit(1)
    }

    private var timingDivider: some View {
        Rectangle()
            .fill(.white.opacity(0.28))
            .frame(width: 1, height: 34)
            .accessibilityHidden(true)
    }

    private func elapsedMetric(_ value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            metricLabel("Leg timer")
            metricValue(value)
                .accessibilityIdentifier("amendment-leg-elapsed")
                .accessibilityLabel("Leg timer, \(value)")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func etaMetric(_ value: String, revised: Bool, passed: Bool) -> some View {
        let provenance = revised ? "Revised elapsed" : "Planned elapsed"
        return VStack(alignment: .leading, spacing: 1) {
            metricLabel("Next ETA")
            if compact {
                metricValue(value)
                    .accessibilityIdentifier("amendment-leg-eta")
                    .accessibilityLabel("Next ETA, \(value), \(provenance)")
                if passed { etaPassed }
            } else {
                HStack(alignment: .center, spacing: 8) {
                    metricValue(value)
                        .accessibilityIdentifier("amendment-leg-eta")
                        .accessibilityLabel("Next ETA, \(value), \(provenance)")
                    if passed { etaPassed }
                }
            }
            if !compact || !passed {
                Text(provenance)
                    .font(.caption2)
                    .foregroundStyle(secondaryInk)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func metricLabel(_ label: String) -> some View {
        Text(label)
            .font(.caption)
            .foregroundStyle(secondaryInk)
            .accessibilityHidden(true)
    }

    private func metricValue(_ value: String) -> some View {
        Text(value)
            .font(.title2.weight(.semibold).monospacedDigit())
            .fixedSize()
    }

    private var etaPassed: some View {
        Text("ETA passed")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(dueInk)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(dueInk.opacity(0.14), in: RoundedRectangle(cornerRadius: 5))
    }
}

private struct RouteAmendmentDisabledOpacity: ViewModifier {
    @Environment(\.isEnabled) private var isEnabled

    func body(content: Content) -> some View {
        content.opacity(isEnabled ? 1 : 0.48)
    }
}

struct RouteAmendmentLegend: View {
    var body: some View {
        ViewThatFits(in: .horizontal) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 10) { retained; bypassed }
                HStack(spacing: 10) { proposed; marks }
            }
            VStack(alignment: .leading, spacing: 4) { retained; bypassed; proposed; marks }
        }
        .font(.caption.weight(.semibold))
        .padding(9)
        .background(Color(uiColor: .systemBackground), in: .rect(cornerRadius: 9))
        .accessibilityElement(children: .combine)
        .allowsHitTesting(false)
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
            .fixedSize(horizontal: true, vertical: false)
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
        .fixedSize(horizontal: true, vertical: false)
    }
}
