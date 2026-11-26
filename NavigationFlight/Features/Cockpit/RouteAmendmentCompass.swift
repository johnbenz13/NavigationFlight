import SwiftUI

/// Owns touch presentation only. Magnetic values remain in the directed-leg entry.
struct RouteAmendmentCompass: View {
    let heading: Int?
    let onSelection: (Int) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .largeTitle) private var compassHeight = 176
    @State private var motion = RouteAmendmentHeadingMotion()
    @State private var isDragging = false
    @State private var coast: Task<Void, Never>?
    @State private var isCoasting = false

    var body: some View {
        GeometryReader { geometry in
            let height = geometry.size.height
            let radius = min(geometry.size.width / 2 - 24, height - 12)
            let center = CGPoint(x: geometry.size.width / 2, y: height - 6)
            let degrees = isDragging || isCoasting ? motion.degrees : Double(heading ?? 360)
            ZStack(alignment: .top) {
                Canvas { context, _ in
                    for tick in 0..<360 {
                        var angle = (Double(tick) - degrees).truncatingRemainder(dividingBy: 360)
                        if angle > 180 { angle -= 360 }
                        if angle < -180 { angle += 360 }
                        guard abs(angle) <= 90 else { continue }
                        let radians = angle * .pi / 180
                        let major = tick % 10 == 0
                        let length: CGFloat = tick % 30 == 0 ? 14 : major ? 9 : 4
                        let outer = point(center, radius: radius, angle: radians)
                        let inner = point(center, radius: radius - length, angle: radians)
                        var path = Path()
                        path.move(to: outer)
                        path.addLine(to: inner)
                        context.stroke(path, with: .color(.secondary.opacity(major ? 0.8 : 0.5)), lineWidth: major ? 1 : 0.5)
                        if tick % (dynamicTypeSize.isAccessibilitySize ? 90 : 30) == 0 {
                            let label = tick == 0 ? "N" : tick == 90 ? "E" : tick == 180 ? "S" : tick == 270 ? "W" : String(tick)
                            context.draw(Text(label).font(.caption).foregroundStyle(.secondary),
                                         at: point(center, radius: radius - 28, angle: radians))
                        }
                    }
                }
                .accessibilityHidden(true)
                RoundedRectangle(cornerRadius: 1)
                    .fill(RouteAmendmentPanelStyle.reference)
                    .frame(width: 3, height: 26)
                    .offset(y: center.y - radius - 12)
                    .accessibilityHidden(true)
                VStack(spacing: 8) {
                    Text(heading.map { String(format: "%03d°", $0) } ?? "Not set")
                        .font(.largeTitle.weight(.semibold)).monospacedDigit()
                    Text("MAGNETIC").font(.caption2).foregroundStyle(.secondary)
                    if !dynamicTypeSize.isAccessibilitySize {
                        Text("Flick for speed · drag slowly for 1°")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                }
                .padding(.top, dynamicTypeSize.isAccessibilitySize ? 0 : height * 0.36)
                .accessibilityHidden(true)
            }
            .contentShape(interactionBand(center: center, radius: radius))
            .clipped()
            .gesture(drag(center: center, radius: radius))
        }
        // Keep the enlarged upright value above the arc rather than letting
        // scaled height push its labels into the readout at accessibility sizes.
        .frame(height: dynamicTypeSize.isAccessibilitySize ? 360 : compassHeight)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Magnetic heading")
        .accessibilityValue(heading.map { String(format: "%03d degrees", $0) } ?? "Not set")
        .accessibilityHint("Adjust by one degree. Clear is a separate action.")
        .accessibilityAdjustableAction { direction in
            stop()
            switch direction {
            case .increment: onSelection(heading.map { $0 == 360 ? 1 : $0 + 1 } ?? 1)
            case .decrement: onSelection(heading.map { $0 == 1 ? 360 : $0 - 1 } ?? 360)
            @unknown default: break
            }
        }
        .accessibilityIdentifier("amendment-field-heading")
        .onChange(of: heading) { _, value in if value == nil { stop() } }
        .onChange(of: reduceMotion) { _, _ in stop() }
        .onDisappear(perform: stop)
    }

    private func point(_ center: CGPoint, radius: CGFloat, angle: Double) -> CGPoint {
        CGPoint(x: center.x + sin(angle) * radius, y: center.y - cos(angle) * radius)
    }

    /// Restrict angular input to the visible card. The upright value and space
    /// around the arc remain available to the containing editor's scroll view.
    private func interactionBand(center: CGPoint, radius: CGFloat) -> Path {
        Path { path in
            for degree in stride(from: -90.0, through: 90, by: 3) {
                let location = point(center, radius: radius, angle: degree * .pi / 180)
                if degree == -90 { path.move(to: location) } else { path.addLine(to: location) }
            }
            for degree in stride(from: 90.0, through: -90, by: -3) {
                path.addLine(to: point(center, radius: max(0, radius - 44), angle: degree * .pi / 180))
            }
            path.closeSubpath()
        }
    }

    private func angle(_ location: CGPoint, center: CGPoint) -> Double {
        atan2(location.x - center.x, center.y - location.y) * 180 / .pi
    }

    private func drag(center: CGPoint, radius: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if !isDragging {
                    stop()
                    motion.begin(angle: angle(value.startLocation, center: center), heading: heading)
                    isDragging = true
                }
                // The upright value's center is not a useful angular lever.
                guard hypot(value.location.x - center.x, value.location.y - center.y) > radius * 0.3 else { return }
                if let selected = motion.move(angle: angle(value.location, center: center)), selected != heading {
                    onSelection(selected)
                }
            }
            .onEnded { value in
                isDragging = false
                let radians = angle(value.location, center: center) * .pi / 180
                let tangentVelocity = value.velocity.width * cos(radians) + value.velocity.height * sin(radians)
                let velocity = -tangentVelocity / max(radius, 1) * 180 / .pi
                let travel = RouteAmendmentHeadingMotion.coastTravel(velocity: velocity, reduceMotion: reduceMotion)
                guard travel != 0, heading != nil else { return }
                let start = motion.degrees
                isCoasting = true
                coast = Task { @MainActor in
                    let clock = ContinuousClock()
                    let began = clock.now
                    var lastSelection = motion.heading
                    while !Task.isCancelled {
                        do { try await Task.sleep(for: .milliseconds(16)) } catch { return }
                        guard !Task.isCancelled else { return }
                        let elapsed = began.duration(to: clock.now)
                        let seconds = Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) / 1e18
                        let progress = min(1, seconds / 0.35)
                        motion.degrees = start + travel * (1 - pow(1 - progress, 3))
                        if motion.heading != lastSelection {
                            lastSelection = motion.heading
                            onSelection(lastSelection)
                        }
                        if progress == 1 { break }
                    }
                    isCoasting = false
                    coast = nil
                }
            }
    }

    private func stop() {
        coast?.cancel()
        coast = nil
        isCoasting = false
        isDragging = false
    }
}
