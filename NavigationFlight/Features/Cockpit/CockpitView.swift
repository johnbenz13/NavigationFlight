import SwiftUI

fileprivate struct CockpitPresentationData {
    struct PlannedReference {
        let station: String
        let radialFrom: String
        let dmeDistance: String
    }

    struct Frequency {
        let role: String
        let service: String
        let value: String
    }

    struct RouteEvent: Identifiable {
        let id: String
        let normalizedPosition: CGPoint
        let calloutOffset: CGSize
        let trigger: String
        let altitude: String?
        let frequency: Frequency?

        var symbolName: String {
            switch (altitude, frequency) {
            case (.some, .some):
                "arrow.up.and.down.and.arrow.left.and.right"
            case (.some, .none):
                "arrow.up.to.line.compact"
            case (.none, .some):
                "antenna.radiowaves.left.and.right"
            case (.none, .none):
                "diamond"
            }
        }

        var conciseLabel: String {
            switch (altitude, frequency) {
            case let (.some(altitude), .some(frequency)):
                "\(altitude) · \(frequency.value)"
            case let (.some(altitude), .none):
                altitude
            case let (.none, .some(frequency)):
                frequency.value
            case (.none, .none):
                trigger
            }
        }
    }

    enum ReminderState {
        case none
        case nearArrival
        case plannedTimeExceeded
    }

    let leg: String
    let origin: String
    let destination: String
    let pilotHeading: String?
    let plannedCourse: String
    let plannedTime: String
    let elapsedTime: String
    let estimatedRemaining: String
    let altitude: String
    let plannedReference: PlannedReference?
    let primaryFrequency: Frequency?
    let secondaryFrequency: Frequency?
    let routeEvents: [RouteEvent]
    let reminderState: ReminderState

    static let minimal = CockpitPresentationData(
        leg: "LEG 2 / 5",
        origin: "חדרה",
        destination: "עירון",
        pilotHeading: nil,
        plannedCourse: "068° M",
        plannedTime: "04:23",
        elapsedTime: "02:17",
        estimatedRemaining: "02:06",
        altitude: "1,500 ft",
        plannedReference: nil,
        primaryFrequency: Frequency(role: "PRIMARY", service: "Pluto West", value: "118.40 MHz"),
        secondaryFrequency: nil,
        routeEvents: [],
        reminderState: .none
    )

    static let fullyPopulated = CockpitPresentationData(
        leg: "LEG 2 / 5",
        origin: "חדרה",
        destination: "עירון",
        pilotHeading: "074° M",
        plannedCourse: "068° M",
        plannedTime: "04:23",
        elapsedTime: "02:53",
        estimatedRemaining: "01:30",
        altitude: "1,500 ft",
        plannedReference: PlannedReference(station: "HDF", radialFrom: "R-245 FROM", dmeDistance: "18.6 NM DME"),
        primaryFrequency: Frequency(role: "PRIMARY", service: "Pluto West", value: "118.40 MHz"),
        secondaryFrequency: Frequency(role: "ATIS", service: "Ben Gurion", value: "132.50 MHz"),
        routeEvents: [
            RouteEvent(
                id: "altitude-event",
                normalizedPosition: CGPoint(x: 0.40, y: 0.57),
                calloutOffset: CGSize(width: -18, height: -62),
                trigger: "At checkpoint N",
                altitude: "2,000 ft",
                frequency: nil
            ),
            RouteEvent(
                id: "combined-event",
                normalizedPosition: CGPoint(x: 0.61, y: 0.44),
                calloutOffset: CGSize(width: 34, height: 66),
                trigger: "At identification point",
                altitude: "2,500 ft",
                frequency: Frequency(role: "PRIMARY", service: "Pluto East", value: "120.60 MHz")
            )
        ],
        reminderState: .none
    )

    static let nearArrival = withReminder(.nearArrival)
    static let plannedTimeExceeded = withReminder(.plannedTimeExceeded)

    private static func withReminder(_ reminderState: ReminderState) -> CockpitPresentationData {
        CockpitPresentationData(
            leg: fullyPopulated.leg,
            origin: fullyPopulated.origin,
            destination: fullyPopulated.destination,
            pilotHeading: fullyPopulated.pilotHeading,
            plannedCourse: fullyPopulated.plannedCourse,
            plannedTime: fullyPopulated.plannedTime,
            elapsedTime: reminderState == .plannedTimeExceeded ? "04:43" : "02:53",
            estimatedRemaining: reminderState == .plannedTimeExceeded ? "00:00" : "01:30",
            altitude: fullyPopulated.altitude,
            plannedReference: fullyPopulated.plannedReference,
            primaryFrequency: fullyPopulated.primaryFrequency,
            secondaryFrequency: fullyPopulated.secondaryFrequency,
            routeEvents: fullyPopulated.routeEvents,
            reminderState: reminderState
        )
    }
}

private enum MapDisplayMode: String, CaseIterable, Identifiable {
    case labels = "Symbols + Labels"
    case symbolsOnly = "Symbols Only"

    var id: Self { self }
}

private enum CalloutDuration: String, CaseIterable, Identifiable {
    case fiveSeconds = "5 seconds"
    case tenSeconds = "10 seconds"

    var id: Self { self }
}

private enum ReminderLeadTime: String, CaseIterable, Identifiable {
    case sixtySeconds = "60 seconds"
    case ninetySeconds = "90 seconds"
    case twoMinutes = "2 minutes"

    var id: Self { self }
}

struct CockpitView: View {
    private let data: CockpitPresentationData
    @State private var presentedAction: MockAction?
    @State private var showsDisplayOptions = false
    @State private var displayMode: MapDisplayMode
    @State private var selectedEventID: String?
    @State private var isEditingRoute = false
    @State private var calloutDuration = CalloutDuration.fiveSeconds
    @State private var reminderLeadTime = ReminderLeadTime.ninetySeconds
    @State private var automaticRemindersEnabled = false

    init() {
        data = .fullyPopulated
        _displayMode = State(initialValue: .labels)
        _selectedEventID = State(initialValue: nil)
    }

    fileprivate init(
        data: CockpitPresentationData,
        displayMode: MapDisplayMode = .labels,
        selectedEventID: String? = nil
    ) {
        self.data = data
        _displayMode = State(initialValue: displayMode)
        _selectedEventID = State(initialValue: selectedEventID)
    }

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                mapSurface
                    .frame(height: geometry.size.height * 0.74)
                controlPanel
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Color(.systemBackground))
        .sheet(item: $presentedAction) { action in
            mockActionSheet(action)
        }
        .sheet(isPresented: $showsDisplayOptions) {
            displayOptionsSheet
        }
    }

    private var mapSurface: some View {
        GeometryReader { geometry in
            ZStack {
                Color(.secondarySystemBackground)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedEventID = nil
                    }

                schematicGrid
                routeLine(in: geometry.size)
                waypointAnnotations(in: geometry.size)
                eventAnnotations(in: geometry.size)
                schematicNotice
                mapControls
                legHeader

                if isEditingRoute {
                    routeEditingIndicator
                }

                reminderBanner
            }
        }
        .clipped()
    }

    private var schematicGrid: some View {
        Canvas { context, size in
            var grid = Path()
            for x in stride(from: CGFloat(0), through: size.width, by: 80) {
                grid.move(to: CGPoint(x: x, y: 0))
                grid.addLine(to: CGPoint(x: x, y: size.height))
            }
            for y in stride(from: CGFloat(0), through: size.height, by: 80) {
                grid.move(to: CGPoint(x: 0, y: y))
                grid.addLine(to: CGPoint(x: size.width, y: y))
            }
            context.stroke(grid, with: .color(.gray.opacity(0.12)), lineWidth: 1)
        }
        .accessibilityHidden(true)
    }

    private func routeLine(in size: CGSize) -> some View {
        let origin = point(x: 0.18, y: 0.69, in: size)
        let destination = point(x: 0.79, y: 0.30, in: size)

        return Canvas { context, _ in
            var route = Path()
            route.move(to: origin)
            route.addLine(to: destination)
            context.stroke(route, with: .color(.blue.opacity(0.82)), style: StrokeStyle(lineWidth: 4, dash: [10, 7]))

            for event in data.routeEvents {
                let position = point(
                    x: event.normalizedPosition.x,
                    y: event.normalizedPosition.y,
                    in: size
                )
                var guide = Path()
                guide.move(to: CGPoint(x: position.x, y: position.y - 12))
                guide.addLine(to: CGPoint(x: position.x, y: position.y + 12))
                context.stroke(guide, with: .color(.blue.opacity(0.35)), lineWidth: 2)
            }
        }
        .accessibilityLabel("Schematic preview of the active leg")
    }

    private func waypointAnnotations(in size: CGSize) -> some View {
        ZStack {
            waypoint(
                title: data.origin,
                subtitle: "DEPARTURE",
                symbol: "circle.fill",
                alignment: .leading
            )
            .position(point(x: 0.18, y: 0.69, in: size))

            VStack(alignment: .leading, spacing: 7) {
                waypoint(
                    title: data.destination,
                    subtitle: "ARRIVAL",
                    symbol: "flag.checkered",
                    alignment: .leading
                )

                if let reference = data.plannedReference {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("PLANNED REFERENCE")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.secondary)
                        Text("\(reference.station) · \(reference.radialFrom)")
                            .font(.caption.weight(.semibold))
                        Text(reference.dmeDistance)
                            .font(.caption)
                            .monospacedDigit()
                    }
                    .padding(8)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                    .accessibilityElement(children: .combine)
                }
            }
            .position(point(x: 0.78, y: 0.35, in: size))
        }
    }

    private func waypoint(
        title: String,
        subtitle: String,
        symbol: String,
        alignment: HorizontalAlignment
    ) -> some View {
        VStack(alignment: alignment, spacing: 3) {
            Image(systemName: symbol)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.blue)
            Text(title)
                .font(.headline)
            Text(subtitle)
                .font(.caption2.weight(.bold))
                .tracking(0.8)
                .foregroundStyle(.secondary)
        }
        .padding(8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 9))
        .accessibilityElement(children: .combine)
    }

    private func eventAnnotations(in size: CGSize) -> some View {
        ZStack {
            ForEach(data.routeEvents) { event in
                eventAnnotation(event)
                    .position(
                        point(
                            x: event.normalizedPosition.x,
                            y: event.normalizedPosition.y,
                            in: size
                        )
                    )
            }
        }
    }

    private func eventAnnotation(_ event: CockpitPresentationData.RouteEvent) -> some View {
        ZStack {
            Button {
                guard displayMode == .symbolsOnly else { return }
                selectedEventID = selectedEventID == event.id ? nil : event.id
            } label: {
                Image(systemName: event.symbolName)
                    .font(.headline.weight(.semibold))
                    .frame(width: 44, height: 44)
                    .foregroundStyle(.white)
                    .background(Color.indigo, in: Circle())
                    .overlay {
                        Circle()
                            .strokeBorder(.white.opacity(0.9), lineWidth: 2)
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Planned event, \(event.trigger), \(event.conciseLabel)")

            if displayMode == .labels {
                conciseEventLabel(event)
                    .offset(event.calloutOffset)
            } else if selectedEventID == event.id {
                expandedEventCallout(event)
                    .offset(event.calloutOffset)
                    .zIndex(2)
            }
        }
    }

    private func conciseEventLabel(_ event: CockpitPresentationData.RouteEvent) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(event.trigger)
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
            Text(event.conciseLabel)
                .font(.caption.weight(.semibold))
                .monospacedDigit()
        }
        .lineLimit(1)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 7))
        .accessibilityElement(children: .combine)
    }

    private func expandedEventCallout(_ event: CockpitPresentationData.RouteEvent) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("PLANNED CHANGE")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.indigo)
            Text(event.trigger)
                .font(.subheadline.weight(.semibold))
            if let altitude = event.altitude {
                Label(altitude, systemImage: "arrow.up.to.line.compact")
            }
            if let frequency = event.frequency {
                Label(
                    "\(frequency.role) · \(frequency.service) · \(frequency.value)",
                    systemImage: "antenna.radiowaves.left.and.right"
                )
            }
            Text("Information only · No action is applied")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .font(.caption)
        .lineLimit(1)
        .padding(10)
        .background(.thickMaterial, in: RoundedRectangle(cornerRadius: 9))
        .overlay {
            RoundedRectangle(cornerRadius: 9)
                .strokeBorder(Color.indigo.opacity(0.35))
        }
        .accessibilityElement(children: .combine)
    }

    private var schematicNotice: some View {
        Text("SCHEMATIC PREVIEW · FICTIONAL POSITIONS · NOT FOR NAVIGATION")
            .font(.caption2.weight(.bold))
            .tracking(0.7)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial, in: Capsule())
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            .padding(.leading, 20)
            .padding(.bottom, 14)
    }

    private var legHeader: some View {
        HStack(spacing: 16) {
            HStack(spacing: 12) {
                Text(data.leg)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text("·")
                    .foregroundStyle(.secondary)
                // Separate RTL names preserve the intended origin → destination order.
                HStack(spacing: 8) {
                    Text(data.origin)
                    Image(systemName: "arrow.right")
                        .font(.caption)
                    Text(data.destination)
                }
                .font(.headline)
                .environment(\.layoutDirection, .leftToRight)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("From \(data.origin) to \(data.destination)")
            }
            Spacer(minLength: 8)
            Button { presentedAction = .charts } label: {
                Label("Charts", systemImage: "map")
                    .font(.headline)
                    .frame(minHeight: 44)
                    .padding(.horizontal, 12)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.primary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(.primary.opacity(0.08))
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .padding(20)
    }

    private var mapControls: some View {
        VStack(spacing: 8) {
            mapControl(
                icon: "slider.horizontal.3",
                label: "Correct",
                isActive: false
            ) {
                presentedAction = .correct
            }
            mapControl(
                icon: "point.topleft.down.to.point.bottomright.curvepath",
                label: "Modify Route",
                isActive: isEditingRoute
            ) {
                isEditingRoute = true
                selectedEventID = nil
            }
            mapControl(
                icon: "map.circle",
                label: "Map Display Options",
                isActive: false
            ) {
                showsDisplayOptions = true
            }
        }
        .padding(8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        .padding(.top, 96)
        .padding(.trailing, 20)
    }

    private func mapControl(
        icon: String,
        label: String,
        isActive: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.headline)
                .frame(width: 44, height: 44)
                .foregroundStyle(isActive ? .white : .primary)
                .background(
                    isActive ? Color.indigo : Color(.tertiarySystemBackground),
                    in: RoundedRectangle(cornerRadius: 9)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private var routeEditingIndicator: some View {
        HStack(spacing: 12) {
            Label("Mock route-editing mode", systemImage: "pencil.line")
                .font(.subheadline.weight(.semibold))
            Text("No route changes are applied")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer(minLength: 8)
            Button("Cancel") {
                isEditingRoute = false
            }
            .buttonStyle(.bordered)
            Button("Done") {
                isEditingRoute = false
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(10)
        .background(.thickMaterial, in: RoundedRectangle(cornerRadius: 10))
        .frame(maxWidth: 520)
        .frame(maxHeight: .infinity, alignment: .top)
        .padding(.top, 96)
    }

    @ViewBuilder
    private var reminderBanner: some View {
        switch data.reminderState {
        case .none:
            EmptyView()
        case .nearArrival:
            reminderContent(
                title: "Estimated waypoint in 01:30",
                cue: "Look outside",
                symbol: "eye"
            )
        case .plannedTimeExceeded:
            reminderContent(
                title: "Planned time exceeded by 00:20",
                cue: "Verify position · Arrival is not confirmed",
                symbol: "exclamationmark.circle"
            )
        }
    }

    private func reminderContent(title: String, cue: String, symbol: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                Text(cue)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(.thickMaterial, in: Capsule())
        .overlay {
            Capsule()
                .strokeBorder(.primary.opacity(0.1))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .padding(.bottom, 48)
        .accessibilityElement(children: .combine)
    }

    private var controlPanel: some View {
        VStack(spacing: 9) {
            HStack(alignment: .top, spacing: 0) {
                headingMetric
                timeMetric
                metric("ALTITUDE", value: data.altitude, detail: "Current planned")
            }

            frequencyRow

            Button { presentedAction = .waypointReached } label: {
                Label("Waypoint Reached", systemImage: "checkmark.circle.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 50)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .background(Color.blue, in: RoundedRectangle(cornerRadius: 10))
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 10)
    }

    private var headingMetric: some View {
        VStack(spacing: 3) {
            Text("HEADING · MAGNETIC")
                .font(.caption.weight(.semibold))
                .tracking(0.8)
                .foregroundStyle(.secondary)
            Text(data.pilotHeading ?? data.plannedCourse)
                .font(.system(size: 30, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
            Text(
                data.pilotHeading == nil
                    ? "Planned course · Heading not set"
                    : "Pilot-provided · Course \(data.plannedCourse)"
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private var timeMetric: some View {
        VStack(spacing: 2) {
            Text("TIME")
                .font(.caption.weight(.semibold))
                .tracking(1)
                .foregroundStyle(.secondary)
            Text(data.elapsedTime)
                .font(.system(size: 32, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
            Text("Elapsed · Planned \(data.plannedTime)")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("Estimated remaining \(data.estimatedRemaining)")
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private func metric(_ title: String, value: String, detail: String) -> some View {
        VStack(spacing: 3) {
            Text(title)
                .font(.caption.weight(.semibold))
                .tracking(1)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 30, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private var frequencyRow: some View {
        HStack(spacing: 18) {
            Text("PLANNED FREQUENCIES")
                .font(.caption2.weight(.bold))
                .tracking(0.7)
                .foregroundStyle(.secondary)
            if let primary = data.primaryFrequency {
                frequencyValue(primary)
            }
            if let secondary = data.secondaryFrequency {
                Divider()
                    .frame(height: 18)
                frequencyValue(secondary)
            }
            Spacer(minLength: 0)
            Text("Not tuned")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(minHeight: 30)
        .padding(.horizontal, 10)
        .overlay(alignment: .top) { Divider() }
        .overlay(alignment: .bottom) { Divider() }
        .accessibilityElement(children: .combine)
    }

    private func frequencyValue(_ frequency: CockpitPresentationData.Frequency) -> some View {
        HStack(spacing: 5) {
            Text(frequency.role)
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
            Text(frequency.service)
                .font(.subheadline)
            Text(frequency.value)
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
        }
        .lineLimit(1)
    }

    private func mockActionSheet(_ action: MockAction) -> some View {
        VStack(spacing: 16) {
            Text(action.rawValue)
                .font(.title2.weight(.semibold))
            Text("UI preview only · Flight controls are not connected.")
                .foregroundStyle(.secondary)
            Button("Done") {
                presentedAction = nil
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
        .padding(32)
        .presentationDetents([.medium])
    }

    private var displayOptionsSheet: some View {
        NavigationStack {
            Form {
                Section("Map annotations") {
                    Picker("Display mode", selection: $displayMode) {
                        ForEach(MapDisplayMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text("Symbols Only reveals one event callout at a time when you tap its symbol. Tap it again or tap the schematic background to dismiss.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Future timing preferences") {
                    Picker("Callout duration", selection: $calloutDuration) {
                        ForEach(CalloutDuration.allCases) { duration in
                            Text(duration.rawValue).tag(duration)
                        }
                    }

                    Picker("Near-arrival lead time", selection: $reminderLeadTime) {
                        ForEach(ReminderLeadTime.allCases) { leadTime in
                            Text(leadTime.rawValue).tag(leadTime)
                        }
                    }

                    Toggle("Automatic reminders at planned event times", isOn: $automaticRemindersEnabled)

                    Text("Preview only. These preferences are not persisted and do not start countdowns, schedule reminders, present or dismiss callouts automatically, change flight values, or imply that the pilot performed an action.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Map Display Options")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        showsDisplayOptions = false
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func point(x: CGFloat, y: CGFloat, in size: CGSize) -> CGPoint {
        CGPoint(x: size.width * x, y: size.height * y)
    }
}

private enum MockAction: String, Identifiable {
    case charts = "Charts"
    case correct = "Correct"
    case waypointReached = "Waypoint Reached"

    var id: Self { self }
}

#Preview("11-inch iPad Portrait · Minimal", traits: .fixedLayout(width: 834, height: 1210)) {
    CockpitView(data: .minimal)
}

#Preview("11-inch iPad Portrait · Full Labels", traits: .fixedLayout(width: 834, height: 1210)) {
    CockpitView(data: .fullyPopulated)
}

#Preview("11-inch iPad Portrait · Symbols Only", traits: .fixedLayout(width: 834, height: 1210)) {
    CockpitView(data: .fullyPopulated, displayMode: .symbolsOnly)
}

#Preview("11-inch iPad Portrait · Expanded Event", traits: .fixedLayout(width: 834, height: 1210)) {
    CockpitView(
        data: .fullyPopulated,
        displayMode: .symbolsOnly,
        selectedEventID: "combined-event"
    )
}

#Preview("11-inch iPad Portrait · Near Arrival", traits: .fixedLayout(width: 834, height: 1210)) {
    CockpitView(data: .nearArrival)
}

#Preview("11-inch iPad Portrait · Planned Time Exceeded", traits: .fixedLayout(width: 834, height: 1210)) {
    CockpitView(data: .plannedTimeExceeded)
}

#Preview("11-inch iPad Portrait · Full · Dark", traits: .fixedLayout(width: 834, height: 1210)) {
    CockpitView(data: .fullyPopulated)
        .preferredColorScheme(.dark)
}
