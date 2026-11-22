import SwiftUI

struct RouteAmendmentChartPanel: View {
    let draft: RouteAmendmentDraft
    let route: RouteAmendmentRoute
    let compact: Bool
    let landscape: Bool
    let camera: AviationMapCameraState?
    let onIntent: (RouteAmendmentDraft.Intent) -> Void
    @FocusState.Binding var swiftUIFocus: RouteAmendmentLegEntry.Field?
    @Binding var nativeFocus: RouteAmendmentLegEntry.Field?

    private var focus: RouteAmendmentLegEntry.Field? { nativeFocus ?? swiftUIFocus }
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var contentHeight: CGFloat = 0
    @State private var footerHeight: CGFloat = 0

    private typealias Style = RouteAmendmentPanelStyle

    var body: some View {
        GeometryReader { geometry in
            if let panel = draft.legPanel {
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
                let inspecting = panel == .inspection
                let leading = inspecting || (landscape && prefersLeadingPanel)
                let inset = horizontalInset(leading: leading, width: geometry.size.width)
                let width = min(geometry.size.width - 2 * inset, inspecting ? 406 : 338)
                let top = verticalInset(geometry.size.height, inspecting: inspecting)
                let pinnedActions = compact && panel == .editor && focus == nil
                let viewportHeight = max(1, geometry.size.height - top - 8)
                VStack(spacing: 0) {
                    ScrollView {
                        panelContent(panel)
                            .onGeometryChange(for: CGFloat.self, of: { $0.size.height }) { contentHeight = $0 }
                    }
                    .scrollBounceBehavior(.basedOnSize)
                    .frame(height: max(1, min(contentHeight == 0 ? viewportHeight : contentHeight,
                                              viewportHeight - (pinnedActions ? footerHeight : 0))))
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
                    RoundedRectangle(cornerRadius: 16).fill(Color(uiColor: .systemBackground))
                        .overlay {
                            if inspecting { RoundedRectangle(cornerRadius: 16).fill(Style.reference.opacity(0.10)) }
                        }
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 16).strokeBorder(.primary.opacity(0.12))
                        .allowsHitTesting(false)
                }
                .clipShape(.rect(cornerRadius: 16))
                .shadow(color: .black.opacity(0.22), radius: 12, y: 5)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("amendment-chart-panel")
                .frame(maxWidth: .infinity, maxHeight: viewportHeight,
                       alignment: leading ? .topLeading : .topTrailing)
                .padding(.horizontal, inset)
                .padding(.top, top)
            }
        }
        .onChange(of: focus) { previous, _ in
            guard let previous, let entry = draft.editor?.entry else { return }
            let finalized = entry.finalizedText(for: previous)
            if finalized != entry[previous] {
                onIntent(.editLegField(previous, finalized))
            }
        }
    }

    private func horizontalInset(leading: Bool, width: CGFloat) -> CGFloat {
        if compact { return 12 }
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
        if focus != nil { return 6 }
        if dynamicTypeSize.isAccessibilitySize { return 8 }
        if compact { return min(75, height * 0.18) }
        return min(inspecting ? 170 : 136, height * 0.25)
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
        .padding(19)
        .frame(maxWidth: .infinity, alignment: .leading)
        .tint(Style.action)
    }

    @ViewBuilder
    private func editorContent(_ editor: RouteAmendmentDraft.Editor, leg: RouteAmendmentDraft.ReviewLeg) -> some View {
        let invalid = editor.showValidation ? editor.entry.invalidFields : []
        if focus == nil {
            Text("PROPOSED LEG · \(draft.mode.title.uppercased())")
                .font(.caption2.weight(.bold)).foregroundStyle(Style.action)
        }
        Text(leg.name).font(.title3.bold()).accessibilityAddTraits(.isHeader)
        if let focus {
            Text(fieldTitle(focus)).font(.caption.weight(.semibold))
        } else {
            Divider()

        }
        entryFields(editor, invalid: invalid, focused: focus)
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
        if editor.showsCues {
            cue(.altitude, placeholder: "ft MSL", entry: editor.entry, invalid: invalid, focused: focus)
            cue(.frequency, placeholder: "MHz", entry: editor.entry, invalid: invalid, focused: focus)
            cue(.visualReference, placeholder: "Landmark note", entry: editor.entry, invalid: invalid, focused: focus)
        }
        if focus != nil {
            action("Done", id: "amendment-keyboard-done", fill: Style.action, ink: .white) {
                swiftUIFocus = nil
                nativeFocus = nil
            }
            .keyboardShortcut(.return, modifiers: [])
        } else {
            if let estimate = editor.estimate { comparison(editor.entry, estimate: estimate) }
            if !compact { saveActions }
            action(editor.estimate == nil ? "Check" : "Hide Check", id: "check-working-amendment-leg",
                   fill: editor.estimate == nil ? Style.check : Style.check.opacity(0.12),
                   ink: editor.estimate == nil ? .white : Style.check) { onIntent(.toggleCheck) }
        }
    }

    private var saveActions: some View {
        adaptiveActions {
            action("Cancel", id: "back-to-amendment-review") { onIntent(.backToLegReview) }
            action("Save leg values", id: "save-amendment-leg-values", fill: Style.action, ink: .white) {
                onIntent(.saveLegValues)
            }
        }
    }

    @ViewBuilder
    private func entryFields(
        _ editor: RouteAmendmentDraft.Editor, invalid: Set<RouteAmendmentLegEntry.Field>,
        focused: RouteAmendmentLegEntry.Field?
    ) -> some View {
        if focused == nil || focused == .heading {
            if focused == nil { fieldCaption("Magnetic heading") }
            stepper(minus: "−1°", plus: "+1°", unit: "degree", invalid: invalid.contains(.heading),
                    adjust: { onIntent(.adjustHeading($0)) }, step: 1) {
                HStack(spacing: 2) {
                    input(.heading, placeholder: "–––", entry: editor.entry, large: true)
                    Text("°").font(.caption).accessibilityHidden(true)
                }
            }
            if invalid.contains(.heading), focused == nil {
                error(editor.entry.heading.isEmpty ? "Enter a magnetic heading." : "Enter a heading from 001 to 360.",
                      id: "amendment-error-heading")
            }
        }
        if focused == nil || focused == .minutes || focused == .seconds {
            if focused == nil { fieldCaption("Flight time") }
            stepper(minus: "−5s", plus: "+5s", unit: "seconds", invalid: invalid.contains(.duration),
                    adjust: { onIntent(.adjustFlightTime($0)) }, step: 5) {
                let layout = dynamicTypeSize.isAccessibilitySize
                    ? AnyLayout(VStackLayout(spacing: 2)) : AnyLayout(HStackLayout(spacing: 3))
                layout {
                    input(.minutes, placeholder: "––", entry: editor.entry, large: true)
                    if !dynamicTypeSize.isAccessibilitySize { Text(":").accessibilityHidden(true) }
                    input(.seconds, placeholder: "––", entry: editor.entry, large: true)
                }
            }
            if invalid.contains(.duration), focused == nil {
                error(editor.entry.duration.isEmpty ? "Enter a flight time." : "Enter a positive time with seconds below 60.",
                      id: "amendment-error-duration")
            }
        }
    }

    private func stepper<Content: View>(
        minus: String, plus: String, unit: String, invalid: Bool, adjust: @escaping (Int) -> Void,
        step: Int, @ViewBuilder content: () -> Content
    ) -> some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 2)) : AnyLayout(HStackLayout(spacing: 3))
        return layout {
            if !dynamicTypeSize.isAccessibilitySize { stepButton(minus, label: "Decrease by \(step) \(unit)") { adjust(-step) } }
            content()
            if dynamicTypeSize.isAccessibilitySize {
                HStack {
                    stepButton(minus, label: "Decrease by \(step) \(unit)") { adjust(-step) }
                    stepButton(plus, label: "Increase by \(step) \(unit)") { adjust(step) }
                }
            } else {
                stepButton(plus, label: "Increase by \(step) \(unit)") { adjust(step) }
            }
        }
        .padding(5)
        .background(invalid ? Color.red.opacity(0.10) : Style.action.opacity(0.10), in: .rect(cornerRadius: 11))
        .overlay {
            RoundedRectangle(cornerRadius: 11).strokeBorder(invalid ? .red.opacity(0.62) : Style.action.opacity(0.16))
        }
    }

    private func stepButton(_ title: String, label: String, perform: @escaping () -> Void) -> some View {
        RepeatingActionButton(action: perform) {
            Text(title).font(.subheadline.weight(.semibold))
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(.rect)
                .foregroundStyle(Style.action)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private func input(
        _ field: RouteAmendmentLegEntry.Field, placeholder: String, entry: RouteAmendmentLegEntry, large: Bool = false
    ) -> some View {
        let text = Binding(get: { entry[field] }, set: { value in
            onIntent(.editLegField(field, value))
        })
        let keyboard: UIKeyboardType = switch field {
        case .heading, .minutes, .seconds: UIDevice.current.userInterfaceIdiom == .pad ? .numbersAndPunctuation : .numberPad
        case .altitude: .numbersAndPunctuation
        case .frequency: UIDevice.current.userInterfaceIdiom == .pad ? .numbersAndPunctuation : .decimalPad
        default: .default
        }
        return HStack(spacing: 2) {
            if field == .heading || field == .seconds {
                RouteAmendmentBoundedField(
                    label: fieldTitle(field),
                    placeholder: placeholder,
                    keyboard: keyboard,
                    field: field,
                    focus: $nativeFocus,
                    text: text,
                    accepts: { entry.allowsInput($0, for: field) }
                )
                .frame(maxWidth: .infinity, minHeight: 44)
            } else {
                textField(field, placeholder: placeholder, text: text, keyboard: keyboard, large: large)
            }
            if field == .minutes || field == .seconds {
                Text(field == .minutes ? "min" : "sec")
                    .font(.caption2).foregroundStyle(.secondary).accessibilityHidden(true)
            }
        }
        .padding(.horizontal, 5)
        .frame(maxWidth: .infinity, minHeight: 44)
        .background(Color(uiColor: .systemBackground).opacity(0.75), in: .rect(cornerRadius: 7))
        .overlay {
            if large { RoundedRectangle(cornerRadius: 7).strokeBorder(Style.action.opacity(0.22)) }
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
            .accessibilityIdentifier("amendment-field-\(field.rawValue)")
    }

    @ViewBuilder
    private func cue(
        _ field: RouteAmendmentLegEntry.Field, placeholder: String, entry: RouteAmendmentLegEntry,
        invalid: Set<RouteAmendmentLegEntry.Field>, focused: RouteAmendmentLegEntry.Field?
    ) -> some View {
        if focused == nil || focused == field {
            VStack(alignment: .leading, spacing: 2) {
                if focused == nil {
                    Text(fieldTitle(field)).font(.caption2).foregroundStyle(.secondary)
                }
                input(field, placeholder: placeholder, entry: entry)
                if invalid.contains(field), focused == nil {
                    error("Enter a valid \(fieldTitle(field).lowercased()).", id: "amendment-error-\(field.rawValue)")
                }
            }
            .padding(6)
            .background(Style.card, in: .rect(cornerRadius: 8))
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
                Text("Pilot heading · \(entry.magneticHeading.map { angle($0) } ?? "Not entered")")
                Text("Pilot flight time · \(entry.durationSeconds.map { time($0) } ?? "Not entered")")
            }
            .font(.caption)
            .foregroundStyle(.primary)
        } else if case .available(let direction, let duration, let provenance) = estimate {
            adaptiveActions {
                infoCard {
                    Text("Pilot entries").font(.caption.weight(.bold))
                    metric("Magnetic heading", value: entry.magneticHeading.map { angle($0) } ?? "Not entered")
                    metric("Flight time", value: entry.durationSeconds.map { time($0) } ?? "Not entered")
                }
                .accessibilityIdentifier("amendment-pilot-entries")
                infoCard {
                    Text("App estimate").font(.caption.weight(.bold))
                    metric(directionLabel(provenance == .noWind ? .noWind : .wind),
                           value: angle(Int(direction.value.rounded()) % 360))
                    metric("Estimated flight time", value: time(duration))
                    Text(provenance == .noWind ? "No wind" : "Planned wind")
                        .font(.caption2.weight(.semibold)).foregroundStyle(Style.reference)
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("amendment-reference-estimate")
            }
        }
    }

    private func angle(_ degrees: Int?) -> String { degrees.map { String(format: "%03d°", $0) } ?? "Unavailable" }
    private func time(_ seconds: Int?) -> String { seconds.map(RouteAmendmentLegEntry.durationText) ?? "Unavailable" }
    private func directionLabel(_ mode: NavigationMode) -> String { mode == .wind ? "Magnetic heading" : "Magnetic course" }

    private func infoCard<Content: View>(caution: Bool = false, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4, content: content)
            .padding(8)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(caution ? .orange.opacity(0.14) : Style.card, in: .rect(cornerRadius: 8))
    }

    private func metric(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title).font(.caption2).foregroundStyle(.secondary)
            Text(value).font(.subheadline.weight(.semibold).monospacedDigit())
        }
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
