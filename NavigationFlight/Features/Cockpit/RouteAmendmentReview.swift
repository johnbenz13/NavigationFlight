import SwiftUI

struct RouteAmendmentReview: View {
    let draft: RouteAmendmentDraft
    let route: RouteAmendmentRoute
    let compact: Bool
    var isPlotting = false
    var isReplacing = false
    let onIntent: (RouteAmendmentDraft.Intent) -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(spacing: 4) {
            ForEach(Array(draft.reviewLegs(on: route).enumerated()), id: \.element.id) { index, leg in
                Button { onIntent(.editLeg(leg.id)) } label: {
                    row(leg, number: index + 1)
                }
                .buttonStyle(RouteAmendmentLegButtonStyle())
                .id(leg.id)
                .accessibilityLabel("Proposed leg \(index + 1), \(leg.name)")
                .accessibilityValue("Magnetic heading \(heading(leg)), leg time \(duration(leg))")
                .accessibilityAddTraits(draft.editor?.id == leg.id ? .isSelected : [])
                .accessibilityIdentifier("edit-amendment-leg")
            }
        }
    }

    private func row(_ leg: RouteAmendmentDraft.ReviewLeg, number: Int) -> some View {
        let selected = draft.editor?.id == leg.id
        return HStack(spacing: 12) {
            if !compact {
                Text("\(number)").font(.subheadline).foregroundStyle(.secondary).frame(width: 28)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(compact ? "\(number)  \(leg.name)" : leg.name)
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
                if compact {
                    if dynamicTypeSize.isAccessibilitySize {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Magnetic heading \(heading(leg))")
                            Text("Leg time \(duration(leg))")
                        }
                        .font(.caption.monospacedDigit())
                        .fixedSize(horizontal: false, vertical: true)
                    } else {
                        Text("Magnetic \(heading(leg)) · Leg time \(duration(leg))  ›")
                            .font(.subheadline.monospacedDigit())
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } else {
                    Text(boundary(leg))
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if !compact {
                Text(heading(leg)).foregroundStyle(leg.values == nil ? .secondary : .primary)
                    .frame(width: 136, alignment: .leading)
                Text(duration(leg)).foregroundStyle(leg.values == nil ? .secondary : .primary)
                    .frame(width: 136, alignment: .leading)
                Image(systemName: "chevron.right").foregroundStyle(.secondary)
            }
        }
        .font(.title3.weight(.semibold).monospacedDigit())
        .padding(.horizontal, compact ? 10 : 16)
        .padding(.vertical, 4)
        .frame(minHeight: compact ? 60 : 50)
        .background(selected ? Color(RouteAmendmentMapOverlay.proposedColor).opacity(0.1) : Color(.secondarySystemBackground),
                    in: .rect(cornerRadius: 12))
        .overlay {
            if selected { RoundedRectangle(cornerRadius: 12).stroke(Color(RouteAmendmentMapOverlay.proposedColor), lineWidth: 1.5) }
        }
    }

    private func heading(_ leg: RouteAmendmentDraft.ReviewLeg) -> String {
        leg.values.map { "\($0.headingText)°" } ?? "Not set"
    }

    private func boundary(_ leg: RouteAmendmentDraft.ReviewLeg) -> String {
        func role(_ endpoint: RouteAmendmentDraft.ReviewLeg.Endpoint) -> String {
            switch endpoint {
            case .point: "Via"
            case .anchor(let anchor): anchor == draft.departure ? route.name(for: anchor) : "Rejoin"
            }
        }
        return "\(role(leg.id.from)) → \(role(leg.id.to))"
    }

    private func duration(_ leg: RouteAmendmentDraft.ReviewLeg) -> String {
        leg.values.map { RouteAmendmentLegEntry.durationText($0.durationSeconds) } ?? "Not set"
    }
}

/// Plotting disables activation, but the formed leg's values must remain readable.
private struct RouteAmendmentLegButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.opacity(configuration.isPressed ? 0.8 : 1)
    }
}

extension RouteAmendmentDraft.ReviewLeg {
    var name: String {
        RouteAmendmentRoute.legName(from: departureName, to: arrivalName)
    }
}

enum RouteAmendmentPanelStyle {
    static let quietTimingSurface = Color(uiColor: .init { traits in
        traits.userInterfaceStyle == .dark ? .secondarySystemBackground
            : .init(red: 0.949, green: 0.969, blue: 0.980, alpha: 1)
    })
    static let overPlannedInk = Color(uiColor: .init { traits in
        traits.userInterfaceStyle == .dark ? .systemOrange
            : .init(red: 0.588, green: 0.322, blue: 0, alpha: 1)
    })
    static let action = Color(uiColor: AviationMapVisualStyle.default.primaryActionColor)
    static let check = Color(uiColor: AviationMapVisualStyle.default.cockpitProgressionActionBackgroundColor)
    static let reference = Color(uiColor: RouteAmendmentMapOverlay.proposedColor)
    static let card = Color(uiColor: .secondarySystemFill)
    static let neutral = Color(uiColor: .tertiarySystemFill)
}
