import SwiftUI

struct PositionCheckRecoveryGuidanceView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let recovery: PositionCheckPresentation.Recovery

    var body: some View {
        Group {
            switch recovery {
            case .guidance(let course, let time, _):
                guidanceCard(course: course, time: time)
            case .onTrack:
                explanation(title: "ON TRACK", detail: "Position remains visible; no corrective course is needed.", color: .green)
            case .positionOnly:
                explanation(title: "POSITION ONLY", detail: "Position available — recovery guidance unavailable.", color: .blue)
            case .noSensibleIntercept(let detail):
                explanation(title: "NO SENSIBLE INTERCEPT", detail: detail, color: accessibleOrange)
            case .extremeDisplacement:
                explanation(
                    title: "OUTSIDE RECOVERY RANGE",
                    detail: "Outside recovery-guidance range — review navigation.",
                    color: .red
                )
            }
        }
        .accessibilityIdentifier("position-check-recovery")
    }

    private func guidanceCard(course: String, time: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("REJOIN ACTIVE LEG")
                .font(.caption2.weight(.bold))
                .foregroundStyle(accessibleOrange)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 28) {
                    metric(title: "SUGGESTED COURSE", value: course)
                    metric(title: "REJOIN IN", value: time)
                }
                VStack(alignment: .leading, spacing: 8) {
                    metric(title: "SUGGESTED COURSE", value: course)
                    metric(title: "REJOIN IN", value: time)
                }
            }
            Text("Apply wind correction")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(width: dynamicTypeSize.isAccessibilitySize ? nil : 284, alignment: .leading)
        .frame(maxWidth: dynamicTypeSize.isAccessibilitySize ? 360 : nil, alignment: .leading)
        .frame(minHeight: 118, alignment: .leading)
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
        .overlay { RoundedRectangle(cornerRadius: 16).stroke(.orange, lineWidth: 1.5) }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(verbatim: "Rejoin active leg. Suggested magnetic course \(course). Rejoin in \(time). Apply wind correction."))
    }

    private func metric(title: LocalizedStringKey, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption2.weight(.bold)).foregroundStyle(.secondary)
            Text(value).font(.title2.weight(.bold)).monospacedDigit()
        }
    }

    private func explanation(title: String, detail: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(verbatim: title).font(.caption2.weight(.bold)).foregroundStyle(color)
            Text(verbatim: detail).font(.caption).foregroundStyle(.primary)
        }
        .padding(12)
        .frame(maxWidth: 360, alignment: .leading)
        .background(.background.opacity(0.94), in: RoundedRectangle(cornerRadius: 14))
        .overlay { RoundedRectangle(cornerRadius: 14).stroke(color, lineWidth: 1.5) }
        .accessibilityElement(children: .combine)
    }

    private var accessibleOrange: Color {
        Color(red: 154 / 255, green: 74 / 255, blue: 0)
    }
}
