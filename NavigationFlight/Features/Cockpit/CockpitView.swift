import SwiftUI

/// Static presentation data for the first cockpit UI checkpoint.
private struct CockpitPreviewData {
    let leg = "LEG 2 / 5"
    let origin = "חדרה"
    let destination = "עירון"
    let heading = "074°"
    let plannedTime = "04:23"
    let elapsedTime = "02:17"
    let altitude = "1500"
    let frequencyName = "Pluto West"
    let frequency = "118.40"
}

struct CockpitView: View {
    private let data = CockpitPreviewData()
    @State private var presentedAction: MockAction?

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                mapSurface
                    // Use safe-area height: the floating header is part of the map.
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
        VStack(spacing: 12) {
            HStack(alignment: .top, spacing: 0) {
                metric("HEADING", value: data.heading, detail: "Planned")
                metric("TIME", value: data.plannedTime, detail: "Planned · \(data.elapsedTime) elapsed")
                metric("ALTITUDE", value: data.altitude + " ft", detail: "Planned")
            }
            HStack {
                Text(data.frequencyName)
                Spacer()
                Text(data.frequency)
                    .fontWeight(.semibold)
                    .monospacedDigit()
                    .accessibilityLabel("Frequency \(data.frequency) megahertz")
            }
            .font(.headline)
            .padding(.vertical, 8)
            .overlay(alignment: .top) { Divider() }
            .overlay(alignment: .bottom) { Divider() }

            HStack(spacing: 12) {
                secondaryButton("Correct", icon: "slider.horizontal.3", action: .correct)
                secondaryButton("Modify Route", icon: "point.topleft.down.to.point.bottomright.curvepath", action: .modifyRoute)
            }
            Button { presentedAction = .waypointReached } label: {
                Label("Waypoint Reached", systemImage: "checkmark")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 52)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .background(Color(red: 0.16, green: 0.29, blue: 0.32), in: RoundedRectangle(cornerRadius: 10))
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
    }

    private func metric(_ title: String, value: String, detail: String) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .tracking(1)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 32, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private func secondaryButton(_ title: String, icon: String, action: MockAction) -> some View {
        Button { presentedAction = action } label: {
            Label(title, systemImage: icon)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 44)
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

// PreviewProvider keeps these device-specific previews usable without macro plugins.
struct CockpitView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            CockpitView()
                .previewDisplayName("11-inch iPad · Portrait")
            CockpitView()
                .preferredColorScheme(.dark)
                .previewDisplayName("11-inch iPad · Portrait · Dark")
        }
        .previewDevice(PreviewDevice(rawValue: "iPad Pro 11-inch (M4)"))
        .previewInterfaceOrientation(.portrait)
    }
}
