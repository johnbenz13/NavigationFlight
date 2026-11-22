import SwiftUI

struct RouteAmendmentReview: View {
    let draft: RouteAmendmentDraft
    let route: RouteAmendmentRoute
    let compact: Bool
    let onIntent: (RouteAmendmentDraft.Intent) -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(spacing: 3) {
            ForEach(draft.reviewLegs(on: route)) { leg in
                let layout = dynamicTypeSize.isAccessibilitySize
                    ? AnyLayout(VStackLayout(alignment: .leading, spacing: 0))
                    : AnyLayout(HStackLayout(spacing: 8))
                layout {
                    Button { onIntent(.editLeg(leg.id)) } label: {
                        legRow(leg)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Proposed leg, \(leg.name)")
                    .accessibilityValue("Heading \(heading(leg)), flight time \(duration(leg))")
                    .accessibilityAddTraits(draft.editor?.id == leg.id ? .isSelected : [])
                    .accessibilityIdentifier("edit-amendment-leg")

                    Button { onIntent(.checkLeg(leg.id)) } label: {
                        Text("Check")
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, compact ? 10 : 24)
                            .frame(minWidth: 44, minHeight: 44)
                            .foregroundStyle(.white)
                            .background(RouteAmendmentPanelStyle.check, in: .rect(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Check estimate for \(leg.name)")
                    .accessibilityIdentifier("check-amendment-leg")
                }
                .padding(.trailing, 6)
                .background(RouteAmendmentPanelStyle.card, in: .rect(cornerRadius: 8))
            }
        }
    }

    private func legRow(_ leg: RouteAmendmentDraft.ReviewLeg) -> some View {
        let layout = compact ? AnyLayout(VStackLayout(alignment: .leading, spacing: 2))
            : AnyLayout(HStackLayout(spacing: 12))
        return HStack(spacing: 8) {
            layout {
                Text(leg.name)
                    .font(.subheadline.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                HStack(spacing: compact ? 8 : 16) {
                    if compact && !dynamicTypeSize.isAccessibilitySize {
                        Text("\(heading(leg)) · \(duration(leg))")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    } else {
                        metric("Heading", value: heading(leg))
                        metric("Flight time", value: duration(leg))
                    }
                }
            }
            Image(systemName: "chevron.forward")
                .font(.caption.weight(.semibold))
                .foregroundStyle(RouteAmendmentPanelStyle.action)
                .padding(.horizontal, compact ? 2 : 12)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, compact ? 4 : 0)
        .frame(minHeight: 44)
        .contentShape(.rect)
    }

    private func metric(_ title: LocalizedStringKey, value: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title).font(.caption2).foregroundStyle(.secondary)
            Text(value).font(.subheadline.weight(.semibold).monospacedDigit())
        }
        .frame(minWidth: compact ? nil : 100, alignment: .leading)
    }

    private func heading(_ leg: RouteAmendmentDraft.ReviewLeg) -> String {
        leg.values.map { "\($0.headingText)°" } ?? "—"
    }

    private func duration(_ leg: RouteAmendmentDraft.ReviewLeg) -> String {
        leg.values.map { RouteAmendmentLegEntry.durationText($0.durationSeconds) } ?? "—"
    }
}

extension RouteAmendmentDraft.ReviewLeg {
    var name: String {
        "\u{2068}\(departureName)\u{2069} → \u{2068}\(arrivalName)\u{2069}"
    }
}

enum RouteAmendmentPanelStyle {
    static let action = Color(uiColor: AviationMapVisualStyle.default.primaryActionColor)
    static let check = Color(uiColor: AviationMapVisualStyle.default.cockpitProgressionActionBackgroundColor)
    static let reference = Color(uiColor: RouteAmendmentMapOverlay.proposedColor)
    static let card = Color(uiColor: .secondarySystemFill)
    static let neutral = Color(uiColor: .tertiarySystemFill)
}
