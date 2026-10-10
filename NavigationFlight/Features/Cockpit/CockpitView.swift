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

    struct UpcomingInstruction {
        let trigger: String
        let altitude: String?
        let frequency: Frequency?
    }

    let leg: String
    let origin: String
    let destination: String
    let pilotHeading: String?
    let plannedCourse: String
    let plannedTime: String
    let elapsedTime: String
    let altitude: String
    let plannedReference: PlannedReference?
    let primaryFrequency: Frequency?
    let secondaryFrequency: Frequency?
    let upcomingInstruction: UpcomingInstruction?

    static let minimal = CockpitPresentationData(
        leg: "LEG 2 / 5",
        origin: "חדרה",
        destination: "עירון",
        pilotHeading: nil,
        plannedCourse: "068° M",
        plannedTime: "04:23",
        elapsedTime: "02:17",
        altitude: "1,500 ft",
        plannedReference: nil,
        primaryFrequency: Frequency(role: "PRIMARY", service: "Pluto West", value: "118.40 MHz"),
        secondaryFrequency: nil,
        upcomingInstruction: nil
    )

    static let fullyPopulated = CockpitPresentationData(
        leg: "LEG 2 / 5",
        origin: "חדרה",
        destination: "עירון",
        pilotHeading: "074° M",
        plannedCourse: "068° M",
        plannedTime: "04:23",
        elapsedTime: "02:17",
        altitude: "1,500 ft",
        plannedReference: PlannedReference(station: "HDF", radialFrom: "R-245 FROM", dmeDistance: "18.6 NM DME"),
        primaryFrequency: Frequency(role: "PRIMARY", service: "Pluto West", value: "118.40 MHz"),
        secondaryFrequency: Frequency(role: "ATIS", service: "Ben Gurion", value: "132.50 MHz"),
        upcomingInstruction: UpcomingInstruction(
            trigger: "At identification point",
            altitude: "2,500 ft",
            frequency: Frequency(role: "PRIMARY", service: "Pluto East", value: "120.60 MHz")
        )
    )
}

struct CockpitView: View {
    private let data: CockpitPresentationData
    @State private var presentedAction: MockAction?

    init() {
        data = .fullyPopulated
    }

    fileprivate init(data: CockpitPresentationData) {
        self.data = data
    }

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                mapSurface
                    // The floating header remains part of the chart-first map region.
                    .frame(height: geometry.size.height * 0.72)
                controlPanel
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Color(.systemBackground))
        .sheet(item: $presentedAction) { action in
            VStack(spacing: 16) {
                Text(action.rawValue)
                    .font(.title2.weight(.semibold))
                Text("UI preview only · Flight controls are not connected.")
                    .foregroundStyle(.secondary)
                Button("Done") { presentedAction = nil }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
            }
            .padding(32)
            .presentationDetents([.medium])
        }
    }

    private var mapSurface: some View {
        ZStack(alignment: .top) {
            Color(red: 0.89, green: 0.91, blue: 0.88)
            // Deliberately schematic: this surface is not a navigation chart.
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
                context.stroke(grid, with: .color(.black.opacity(0.035)), lineWidth: 1)
            }
            .accessibilityHidden(true)

            VStack(spacing: 10) {
                Image(systemName: "map")
                    .font(.system(size: 30, weight: .light))
                Text("MAP PLACEHOLDER")
                    .font(.caption.weight(.semibold))
                    .tracking(2)
                Text("Active leg · Track up")
                    .font(.subheadline)
            }
            .foregroundStyle(Color.black.opacity(0.45))
            .frame(maxWidth: .infinity, maxHeight: .infinity)

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
            .padding(20)
        }
        .clipped()
    }

    private var controlPanel: some View {
        VStack(spacing: 7) {
            HStack(alignment: .top, spacing: 0) {
                headingMetric
                metric("TIME", value: data.plannedTime, detail: "Planned · \(data.elapsedTime) elapsed")
                metric("ALTITUDE", value: data.altitude, detail: "Current planned")
            }

            if let reference = data.plannedReference {
                compactRow(title: "PLANNED REFERENCE") {
                    compactValue(reference.station)
                    compactValue(reference.radialFrom)
                    compactValue(reference.dmeDistance)
                }
            }

            if data.primaryFrequency != nil || data.secondaryFrequency != nil {
                compactRow(title: "PLANNED FREQUENCIES") {
                    if let primary = data.primaryFrequency {
                        frequencyValue(primary)
                    }
                    if let secondary = data.secondaryFrequency {
                        frequencyValue(secondary)
                    }
                }
            }

            if let next = data.upcomingInstruction {
                compactRow(title: "NEXT · \(next.trigger.uppercased())", emphasis: true) {
                    if let altitude = next.altitude {
                        compactValue("ALTITUDE  \(altitude)")
                    }
                    if let frequency = next.frequency {
                        frequencyValue(frequency)
                    }
                }
            }

            HStack(spacing: 12) {
                secondaryButton("Correct", icon: "slider.horizontal.3", action: .correct)
                secondaryButton("Modify Route", icon: "point.topleft.down.to.point.bottomright.curvepath", action: .modifyRoute)
            }

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
                    : "Planned course \(data.plannedCourse)"
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
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

    private func compactRow<Content: View>(
        title: String,
        emphasis: Bool = false,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(spacing: 14) {
            Text(title)
                .font(.caption2.weight(.bold))
                .tracking(0.7)
                .foregroundStyle(emphasis ? Color.blue : .secondary)
                .frame(width: 176, alignment: .leading)
            content()
            Spacer(minLength: 0)
        }
        .frame(minHeight: 23)
        .padding(.horizontal, 10)
        .background(
            emphasis ? Color.blue.opacity(0.08) : Color.clear,
            in: RoundedRectangle(cornerRadius: 6)
        )
        .overlay(alignment: .top) { Divider() }
        .accessibilityElement(children: .combine)
    }

    private func compactValue(_ value: String) -> some View {
        Text(value)
            .font(.subheadline.weight(.semibold))
            .monospacedDigit()
            .lineLimit(1)
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
        .accessibilityLabel("\(frequency.role), \(frequency.service), planned frequency \(frequency.value)")
    }

    private func secondaryButton(_ title: String, icon: String, action: MockAction) -> some View {
        Button { presentedAction = action } label: {
            Label(title, systemImage: icon)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 42)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
    }
}

private enum MockAction: String, Identifiable {
    case charts = "Charts"
    case correct = "Correct"
    case modifyRoute = "Modify Route"
    case waypointReached = "Waypoint Reached"

    var id: String { rawValue }
}

#Preview("11-inch iPad Portrait · Minimal", traits: .fixedLayout(width: 834, height: 1210)) {
    CockpitView(data: .minimal)
}

#Preview("11-inch iPad Portrait · Full", traits: .fixedLayout(width: 834, height: 1210)) {
    CockpitView(data: .fullyPopulated)
}

#Preview("11-inch iPad Portrait · Full · Dark", traits: .fixedLayout(width: 834, height: 1210)) {
    CockpitView(data: .fullyPopulated)
        .preferredColorScheme(.dark)
}
