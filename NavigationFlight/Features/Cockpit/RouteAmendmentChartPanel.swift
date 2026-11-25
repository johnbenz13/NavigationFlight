import SwiftUI
import UIKit

struct RouteAmendmentChartPanel: View {
    let draft: RouteAmendmentDraft
    let route: RouteAmendmentRoute
    let compact: Bool
    let landscape: Bool
    let camera: AviationMapCameraState?
    var headerInset: CGFloat = 0
    let onIntent: (RouteAmendmentDraft.Intent) -> Void
    @FocusState.Binding var swiftUIFocus: RouteAmendmentLegEntry.Field?
    @Binding var nativeFocus: RouteAmendmentLegEntry.Field?

    private var focus: RouteAmendmentLegEntry.Field? { nativeFocus ?? swiftUIFocus }
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var contentHeight: CGFloat = 0
    @State private var footerHeight: CGFloat = 0
    @State private var presentsNativeChoice = false
    @State private var keyboardSafeHeight: CGFloat?

    private typealias Style = RouteAmendmentPanelStyle

    var body: some View {
        GeometryReader { geometry in
            if let panel = draft.legPanel, !usesNativeChoice {
                if draft.isChoosingInspectionLeg, geometry.size.width >= 810, !dynamicTypeSize.isAccessibilitySize {
                    panelContent(.inspection)
                        .frame(width: 406)
                        .background {
                            RoundedRectangle(cornerRadius: 12).fill(Color(uiColor: .systemBackground))
                                .overlay { RoundedRectangle(cornerRadius: 12).fill(Style.reference.opacity(0.10)) }
                        }
                        .padding(.leading, 20)
                        .padding(.top, verticalInset(geometry.size.height, inspecting: true))
                }
                let cornerRadius: CGFloat = panel == .editor ? 18 : 16
                let inspecting = panel == .inspection
                let leading = panel == .editor || inspecting || (landscape && prefersLeadingPanel)
                let inset = horizontalInset(leading: leading, width: geometry.size.width)
                let width = min(geometry.size.width - 2 * inset, panel == .editor ? 390 : inspecting ? 406 : 338)
                let top = verticalInset(geometry.size.height, inspecting: inspecting)
                let pinnedActions = panel == .editor && focus == nil
                // A large resting cockpit can expand the overlay's proposal.
                // Measure the native keyboard boundary instead of subtracting
                // safe-area insets that a smaller proposal may already exclude.
                let availableHeight = focus == nil ? geometry.size.height
                    : min(geometry.size.height, keyboardSafeHeight ?? geometry.size.height)
                let viewportHeight = max(1, availableHeight - top - 8)
                VStack(spacing: 0) {
                    ScrollView {
                        panelContent(panel)
                            .onGeometryChange(for: CGFloat.self, of: { $0.size.height }) { contentHeight = $0 }
                    }
                    .id(draft.editor?.estimate != nil)
                    .scrollBounceBehavior(.basedOnSize)
                    .scrollDismissesKeyboard(focus == nil ? .automatic : .never)
                    .frame(height: panel == .editor && focus == nil
                           ? max(1, min(664, viewportHeight) - footerHeight)
                           : max(1, min(contentHeight == 0 ? viewportHeight : contentHeight,
                                        viewportHeight - (pinnedActions ? footerHeight : 0))))
                    .clipped()
                    if pinnedActions {
                        Divider()
                        saveActions
                            .padding(.horizontal, 16)
                            .padding(.vertical, 6)
                            .onGeometryChange(for: CGFloat.self, of: { $0.size.height + 1 }) { footerHeight = $0 }
                    }
                }
                .frame(width: max(1, width))
                .background {
                    RoundedRectangle(cornerRadius: cornerRadius).fill(Color(uiColor: .systemBackground))
                        .overlay {
                            if inspecting { RoundedRectangle(cornerRadius: cornerRadius).fill(Style.reference.opacity(0.10)) }
                        }
                }
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius).strokeBorder(.primary.opacity(0.12))
                        .allowsHitTesting(false)
                }
                .clipShape(.rect(cornerRadius: cornerRadius))
                .shadow(color: .black.opacity(panel == .editor ? 0.18 : 0.22), radius: panel == .editor ? 8 : 12, y: panel == .editor ? 4 : 5)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("amendment-chart-panel")
                .frame(maxWidth: .infinity, maxHeight: viewportHeight,
                       alignment: leading ? .topLeading : .topTrailing)
                .padding(.horizontal, inset)
                .padding(.top, top)
            }
            nativeChoice

        }
        .background {
            RouteAmendmentKeyboardViewport { keyboardSafeHeight = $0 }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
        .onChange(of: draft.legPanel, initial: true) { _, _ in
            presentsNativeChoice = usesNativeChoice
        }
        .onChange(of: usesNativeChoice) { _, presented in
            presentsNativeChoice = presented
        }
        .onChange(of: focus) { previous, _ in
            guard let previous, let entry = draft.editor?.entry else { return }
            let finalized = entry.finalizedText(for: previous)
            if finalized != entry[previous] {
                onIntent(.editLegField(previous, finalized))
            }
        }
    }

    private var nativeChoice: some View {
        Color.clear
            .confirmationDialog("Edit / Rejoin", isPresented: Binding(
                get: { presentsNativeChoice && isNativeOverlap },
                set: { presentsNativeChoice = $0 }
            ), titleVisibility: .visible) {
                Button("Edit") { onIntent(.resolveDrawingOverlap(rejoin: false)) }
                    .accessibilityIdentifier("amendment-overlap-edit")
                Button("Rejoin") { onIntent(.resolveDrawingOverlap(rejoin: true)) }
                    .accessibilityIdentifier("amendment-overlap-rejoin")
                Button("Cancel", role: .cancel) { onIntent(.closeLegPanel) }
            }
            .sheet(isPresented: Binding(get: { usesNativeChoice && !isNativeOverlap }, set: { _ in })) {
                NavigationStack {
                    List {
                        if case .chooser(let choices, false, _) = draft.legPanel {
                            ForEach(draft.legChoiceRows(choices, on: route)) { row in
                                Button(row.name) { onIntent(.selectLeg(row.id)) }
                                    .accessibilityIdentifier("choose-amendment-proposed-row")
                            }
                        }
                    }
                    .navigationTitle("Choose a leg")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { onIntent(.closeLegPanel) }
                        }
                    }
                }
                .interactiveDismissDisabled()
            }
    }

    private var isNativeOverlap: Bool {
        if case .drawingOverlap = draft.legPanel { return true }
        return false
    }

    private var usesNativeChoice: Bool {
        guard compact, dynamicTypeSize.isAccessibilitySize else { return false }
        return switch draft.legPanel {
        case .drawingOverlap, .chooser(_, false, _): true
        default: false
        }
    }

    private func horizontalInset(leading: Bool, width: CGFloat) -> CGFloat {
        if compact { return draft.legPanel == .editor ? 8 : 12 }
        if landscape || leading || focus != nil { return 20 }
        return min(50, max(20, (width - 338) / 2))
    }

    private var prefersLeadingPanel: Bool {
        guard let camera, let endpoints = draft.selectedLegEndpoints(on: route) else { return false }
        let from = endpoints.0
        let to = endpoints.1
        let longitude = from.longitudeDegrees
            + RouteAmendmentRoute.longitudeDelta(from.longitudeDegrees, to.longitudeDegrees) / 2
        let east = RouteAmendmentRoute.longitudeDelta(camera.center.longitude, longitude) * .pi / 180
        let north = (RouteAmendmentRoute.mercatorY(from.latitudeDegrees)
                     + RouteAmendmentRoute.mercatorY(to.latitudeDegrees)) / 2
            - RouteAmendmentRoute.mercatorY(camera.center.latitude)
        let bearing = camera.direction * .pi / 180
        return east * cos(bearing) - north * sin(bearing) > 0
    }

    private func verticalInset(_ height: CGFloat, inspecting: Bool) -> CGFloat {
        let preferred: CGFloat
        if focus != nil { preferred = compact ? 75 : 84 }
        else if dynamicTypeSize.isAccessibilitySize { preferred = 8 }
        else if draft.legPanel == .editor { preferred = compact ? 50 : 98 }
        else if compact { preferred = min(75, height * 0.18) }
        else { preferred = min(inspecting ? 170 : 136, height * 0.25) }
        // The pencil remains reachable even when the header wraps at Larger Text.
        return max(preferred, headerInset + 8)
    }

    @ViewBuilder
    private func panelContent(_ panel: RouteAmendmentDraft.LegPanel) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            switch panel {
            case .editor:
                if let editor = draft.editor,
                   let leg = draft.reviewLegs(on: route).first(where: { $0.id == editor.id }) {
                    editorContent(editor, leg: leg)
                }
            case .drawingOverlap:
                Text("Edit / Rejoin").font(.headline)
                Button { onIntent(.resolveDrawingOverlap(rejoin: false)) } label: {
                    Text("Edit").frame(maxWidth: .infinity, minHeight: 44).contentShape(.rect)
                }
                .accessibilityIdentifier("amendment-overlap-edit")
                Button { onIntent(.resolveDrawingOverlap(rejoin: true)) } label: {
                    Text("Rejoin").frame(maxWidth: .infinity, minHeight: 44).contentShape(.rect)
                }
                .accessibilityIdentifier("amendment-overlap-rejoin")
                Button { onIntent(.closeLegPanel) } label: {
                    Text("Cancel").frame(maxWidth: .infinity, minHeight: 44).contentShape(.rect)
                }
            case .inspection:
                inspection
            case .chooser(let choices, let inspecting, let overlap):
                chooser(choices, inspecting: inspecting, overlap: overlap)
            case .original(let id, let inspecting):
                if let original = route.originalLeg(id) {
                    originalReference(original, inspecting: inspecting)
                }
            }
        }
        .padding(draft.legPanel == .editor ? 16 : 19)
        .frame(maxWidth: .infinity, alignment: .leading)
        .tint(Style.action)
    }

    @ViewBuilder
    private func editorContent(_ editor: RouteAmendmentDraft.Editor, leg: RouteAmendmentDraft.ReviewLeg) -> some View {
        let invalid = editor.entry.invalidEnteredFields
        if focus == nil {
            let number = (draft.reviewLegs(on: route).firstIndex(where: { $0.id == leg.id }) ?? 0) + 1
            Text("\(draft.mode.title.uppercased()) · LEG \(number) · MAGNETIC")
                .font(.caption.weight(.semibold)).foregroundStyle(Style.reference)
        }
        Text(leg.name).font(.title3.bold()).accessibilityAddTraits(.isHeader)
        if let focus {
            Text(fieldTitle(focus)).font(.caption.weight(.semibold))
        }
        if let estimate = editor.estimate, focus == nil {
            comparison(editor.entry, estimate: estimate)
        } else {
            entryFields(editor, invalid: invalid, focused: focus)
        }
        if focus == nil {
            if let id = editor.referenceID, let reference = route.originalLeg(id) {
                referenceSummary(reference)
            }
            adaptiveActions {
                link("Inspect original leg", id: "inspect-amendment-original") { onIntent(.inspectOriginal) }
                link(editor.showsCues ? "Optional cues ▾" : "Optional cues ›", id: "toggle-amendment-cues") {
                    onIntent(.toggleCues)
                }
            }
        }
        if focus == nil, dynamicTypeSize.isAccessibilitySize {
            Text("Done keeps each entry, even if a field is missing.")
                .font(.caption2).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        if editor.showsCues {
            if focus == nil {
                RouteAmendmentCueSection(entry: editor.entry, onIntent: onIntent)
            }
            cue(.visualReference, placeholder: "Landmark note", entry: editor.entry, invalid: invalid, focused: focus)
            if focus == nil {
                Text("Cues are advisory leg-start references.")
                    .font(.caption).foregroundStyle(.secondary)
                link("Clear note", id: "clear-amendment-note") {
                    onIntent(.editLegField(.visualReference, ""))
                }
            }
        }
        if focus != nil {
            action("Done", id: "amendment-keyboard-done", fill: Style.action, ink: .white) {
                swiftUIFocus = nil
                nativeFocus = nil
            }
            .keyboardShortcut(.return, modifiers: [])
        }
    }

    private var saveActions: some View {
        VStack(alignment: .leading, spacing: 8) {
            adaptiveActions {
                Button { onIntent(.toggleCheck) } label: {
                    Text(draft.editor?.estimate == nil ? "Check" : "Back to values")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.bordered)
                .tint(Style.action)
                .accessibilityIdentifier("check-working-amendment-leg")
                Button { onIntent(.saveLegValues) } label: {
                    Text("Done").frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .tint(Style.action)
                .accessibilityIdentifier("save-amendment-leg-values")
            }
            if !dynamicTypeSize.isAccessibilitySize {
                Text("Done keeps each entry, even if a field is missing.")
                    .font(.caption2).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder
    private func entryFields(
        _ editor: RouteAmendmentDraft.Editor, invalid: Set<RouteAmendmentLegEntry.Field>,
        focused: RouteAmendmentLegEntry.Field?
    ) -> some View {
        if focused == nil {
            RouteAmendmentHeadingSection(entry: editor.entry, onIntent: onIntent)
            Divider().padding(.vertical, 8)
        }
        if focused == nil {
            RouteAmendmentTimeSection(entry: editor.entry, onIntent: onIntent)
        }
    }

    private func textField(
        _ field: RouteAmendmentLegEntry.Field, placeholder: String, text: Binding<String>,
        keyboard: UIKeyboardType, large: Bool
    ) -> some View {
        TextField(fieldTitle(field), text: text, prompt: Text(placeholder),
                  axis: field == .visualReference ? .vertical : .horizontal)
            .keyboardType(keyboard)
            .autocorrectionDisabled(field != .visualReference)
            .textInputAutocapitalization(field == .visualReference ? .sentences : .never)
            .focused($swiftUIFocus, equals: field)
            .font(large ? .title2.weight(.bold).monospacedDigit() : .subheadline)
            .multilineTextAlignment(large ? .center : .leading)
            .accessibilityLabel(fieldTitle(field))
            .accessibilityIdentifier("amendment-field-\(field.rawValue)")
    }

    @ViewBuilder
    private func cue(
        _ field: RouteAmendmentLegEntry.Field, placeholder: String, entry: RouteAmendmentLegEntry,
        invalid: Set<RouteAmendmentLegEntry.Field>, focused: RouteAmendmentLegEntry.Field?
    ) -> some View {
        if focused == nil || focused == field {
            VStack(alignment: .leading, spacing: 8) {
                if focused == nil {
                    Text("Visual reference · optional").font(.subheadline.weight(.semibold))
                }
                textField(field, placeholder: placeholder,
                          text: Binding(get: { entry[field] }, set: { onIntent(.editLegField(field, $0)) }),
                          keyboard: .default, large: false)
                    .padding(12)
                    .frame(maxWidth: .infinity, minHeight: 86, alignment: .topLeading)
                    .background(Style.card, in: .rect(cornerRadius: 10))
            }
        }
    }

    private func fieldTitle(_ field: RouteAmendmentLegEntry.Field) -> String {
        switch field {
        case .heading: "Magnetic heading"
        case .duration: "Flight time"
        case .minutes: "Flight time minutes"
        case .seconds: "Flight time seconds"
        case .altitude: "Altitude"
        case .frequency: "Frequency"
        case .visualReference: "Visual-reference note"
        }
    }

    private func fieldCaption(_ title: LocalizedStringKey) -> some View {
        Text(title).font(.caption.weight(.semibold)).foregroundStyle(Style.action)
    }

    private func error(_ message: String, id: String) -> some View {
        Text(message)
            .font(.caption.weight(.semibold))
            .foregroundStyle(Color(uiColor: .label))
            .accessibilityIdentifier(id)
    }

    private func referenceSummary(_ original: RouteAmendmentRoute.OriginalLeg) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Original reference · \(original.name)").font(.caption.weight(.semibold)).foregroundStyle(Style.reference)
            Text("\(angle(original.direction)) \(directionLabel(original.mode).lowercased()) · \(time(original.durationSeconds)) full flight time")
                .font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(Style.reference.opacity(0.11), in: .rect(cornerRadius: 8))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("amendment-original-summary")
    }

    private func originalReference(_ original: RouteAmendmentRoute.OriginalLeg, inspecting: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ORIGINAL LEG · FLIGHT PLAN").font(.caption2.weight(.bold)).foregroundStyle(Style.reference)
            Text(original.name).font(.title3.bold()).accessibilityAddTraits(.isHeader)
            Divider()
            infoCard {
                originalMetric(directionLabel(original.mode), value: angle(original.direction))
                originalMetric("Full planned flight time", value: time(original.durationSeconds))
            }
            action(inspecting && draft.editor != nil ? "Back to editor" : "Close reference",
                   id: "close-amendment-original", fill: Style.action, ink: .white) { onIntent(.closeLegPanel) }

        }
    }

    private func originalMetric(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.subheadline).foregroundStyle(.secondary)
            Text(value).font(.title2.bold().monospacedDigit())
        }
        .padding(.vertical, 2)
    }

    private var inspection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Inspect original leg is active")
                .font(.headline).foregroundStyle(Style.reference).accessibilityAddTraits(.isHeader)
            Text(draft.message ?? "Tap an original leg or use Choose original leg.")
                .font(.subheadline)
            adaptiveActions {
                link("Cancel inspection", id: "cancel-amendment-inspection") { onIntent(.cancelInspection) }
                action("Choose original leg", id: "choose-original-amendment-leg", fill: Style.action, ink: .white) {
                    onIntent(.chooseLeg)
                }
            }
        }
    }

    private func chooser(_ choices: [RouteAmendmentDraft.LegChoice], inspecting: Bool, overlap: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(inspecting ? "Choose an original leg" : "Choose a leg")
                .font(.headline).accessibilityAddTraits(.isHeader)
            if overlap || !inspecting {
                Text(overlap ? "More than one leg matches this point." : "Select an original or proposed leg.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            ForEach(draft.legChoiceRows(choices, on: route)) { row in
                choiceRow(row.id, name: row.name, proposed: row.isProposed)
            }
            action("Cancel", id: "cancel-amendment-leg-choice") { onIntent(.closeLegPanel) }
        }
    }

    private func choiceRow(_ choice: RouteAmendmentDraft.LegChoice, name: String, proposed: Bool) -> some View {
        Button { onIntent(.selectLeg(choice)) } label: {
            HStack {
                Text(name).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(proposed ? "Proposed" : "Original")
                    .font(.caption.weight(.semibold)).foregroundStyle(proposed ? Style.reference : .secondary)
                Image(systemName: "chevron.forward").font(.caption).foregroundStyle(Style.action)
            }
            .padding(.horizontal, 9)
            .frame(minHeight: 44)
            .contentShape(.rect)
            .background(Style.card, in: .rect(cornerRadius: 9))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(name), \(proposed ? "Proposed" : "Original")")
        .accessibilityIdentifier(proposed ? "choose-amendment-proposed-row" : "choose-amendment-original-row")
    }

    @ViewBuilder
    private func comparison(_ entry: RouteAmendmentLegEntry, estimate: RouteAmendmentEstimator.Result) -> some View {
        if case .unavailable = estimate {
            infoCard(caution: true) {
                Text("App estimate unavailable").font(.subheadline.weight(.semibold))
                    .accessibilityIdentifier("amendment-estimate-unavailable")
                Text("The app cannot calculate a reference estimate for this leg with the current planning inputs. Keep entering your own values.")
                    .accessibilityIdentifier("amendment-estimate-unavailable-guidance")
                Text("Pilot heading · \(entry.magneticHeading.map { angle($0) } ?? "Not set")")
                Text("Pilot leg time · \(entry.durationSeconds.map { time($0) } ?? "Not set")")
            }
            .font(.caption)
            .foregroundStyle(.primary)
        } else if case .available(let direction, let duration, let provenance) = estimate {
            VStack(alignment: .leading, spacing: 8) {
                infoCard {
                    Text("Your entries").font(.headline)
                    metric("Magnetic heading", value: entry.magneticHeading.map { angle($0) } ?? "Not set")
                    metric("Leg time", value: entry.durationSeconds.map { time($0) } ?? "Not set")
                }
                .accessibilityIdentifier("amendment-pilot-entries")
                infoCard(reference: true) {
                    Text("App estimate").font(.caption.weight(.bold))
                    metric(directionLabel(provenance == .noWind ? .noWind : .wind),
                           value: angle(Int(direction.value.rounded()) % 360))
                    metric("Leg time", value: time(duration))
                    Text(provenance == .noWind ? "No wind" : "Planned wind")
                        .font(.caption2.weight(.semibold)).foregroundStyle(Style.reference)
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("amendment-reference-estimate")
                Text("Your entries stay unchanged.").font(.subheadline.weight(.semibold))
                if provenance == .noWind {
                    Text("No-wind magnetic course is reference only; it does not replace your magnetic heading.")
                        .font(.caption).foregroundStyle(.secondary)
                        .accessibilityIdentifier("amendment-estimate-course-guidance")
                }
                Text("Manual legs show no minute marks or drift lines after Check.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func angle(_ degrees: Int?) -> String { degrees.map { String(format: "%03d°", $0) } ?? "Unavailable" }
    private func time(_ seconds: Int?) -> String { seconds.map(RouteAmendmentLegEntry.durationText) ?? "Unavailable" }
    private func directionLabel(_ mode: NavigationMode) -> String { mode == .wind ? "Magnetic heading" : "Magnetic course" }

    private func infoCard<Content: View>(caution: Bool = false, reference: Bool = false, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4, content: content)
            .padding(8)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(caution ? .orange.opacity(0.14) : reference ? Style.reference.opacity(0.10) : Style.card, in: .rect(cornerRadius: 8))
    }

    private func metric(_ title: String, value: String) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(title).fixedSize()
                Spacer(minLength: 0)
                Text(value).monospacedDigit().fixedSize()
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                Text(value).monospacedDigit()
            }
        }
        .font(.headline)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func adaptiveActions<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 8))
        return layout { content() }
    }

    private func action(
        _ title: LocalizedStringKey, id: String, fill: Color = Style.neutral,
        ink: Color = .primary, perform: @escaping () -> Void
    ) -> some View {
        Button(action: perform) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(ink)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 5)
                .padding(.vertical, 3)
                .frame(maxWidth: .infinity, minHeight: 44)
                .contentShape(.rect)
                .background(fill, in: .rect(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(id)
    }

    private func link(_ title: LocalizedStringKey, id: String, perform: @escaping () -> Void) -> some View {
        action(title, id: id, fill: .clear, ink: Style.action, perform: perform)
    }
}

/// Bridges native keyboard frames without global screen-size assumptions or Combine.
private struct RouteAmendmentKeyboardViewport: UIViewRepresentable {
    let onHeightChange: (CGFloat) -> Void

    func makeUIView(context: Context) -> MeasurementView { MeasurementView() }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: MeasurementView, context: Context) -> CGSize? {
        proposal.replacingUnspecifiedDimensions()
    }

    func updateUIView(_ view: MeasurementView, context: Context) {
        view.onHeightChange = onHeightChange
        view.setNeedsLayout()
    }

    final class MeasurementView: UIView {
        var onHeightChange: ((CGFloat) -> Void)?
        private var keyboardFrame: CGRect?
        private weak var keyboardScreen: UIScreen?
        private var reportedHeight: CGFloat?

        init() {
            super.init(frame: .zero)
            isUserInteractionEnabled = false
            NotificationCenter.default.addObserver(
                self, selector: #selector(keyboardFrameChanged(_:)),
                name: UIResponder.keyboardWillChangeFrameNotification, object: nil
            )
        }

        required init?(coder: NSCoder) { nil }

        deinit { NotificationCenter.default.removeObserver(self) }

        @objc private func keyboardFrameChanged(_ notification: Notification) {
            guard let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue,
                  let screen = notification.object as? UIScreen else { return }
            keyboardFrame = frame.cgRectValue
            keyboardScreen = screen
            setNeedsLayout()
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            guard let window, bounds.height > 0 else { return }
            var height = bounds.height
            if let keyboardFrame, let keyboardScreen,
               keyboardScreen === window.windowScene?.screen {
                // UIKit supplies screen coordinates, including keyboard accessories.
                // Convert through the posting screen for Split View/window correctness.
                let localFrame = keyboardScreen.coordinateSpace.convert(keyboardFrame, to: self)
                let overlap = bounds.intersection(localFrame)
                if !overlap.isNull, !overlap.isEmpty { height = max(0, overlap.minY) }
            }
            guard reportedHeight.map({ abs($0 - height) > 0.5 }) ?? true else { return }
            reportedHeight = height
            // Defer the SwiftUI state update until UIKit's layout callback ends.
            Task { @MainActor [weak self] in
                guard let self, self.window != nil, self.reportedHeight == height else { return }
                self.onHeightChange?(height)
            }
        }
    }
}
