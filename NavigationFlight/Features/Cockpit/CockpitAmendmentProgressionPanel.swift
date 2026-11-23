import SwiftUI

struct CockpitAmendmentProgressionPanel<RecordingStatus: View, PositionControl: View, SecondaryActions: View, PrimaryAction: View>: View {
    let routeName: String
    let heading: String
    let flightTime: String
    let startedAt: Date?
    let legIndex: Int
    let immediateDeparture: Bool
    let isActive: Bool
    let compact: Bool
    let altitudeFeet: Double
    let frequencyMHz: Double?
    let visualReference: String?
    let onEditHeading: () -> Void
    @ViewBuilder let recordingStatus: () -> RecordingStatus
    @ViewBuilder let positionControl: () -> PositionControl
    @ViewBuilder let secondaryActions: () -> SecondaryActions
    @ViewBuilder let primaryAction: () -> PrimaryAction

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorScheme) private var colorScheme

    private var singleColumn: Bool { compact || dynamicTypeSize.isAccessibilitySize }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    let headerLayout = singleColumn
                        ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
                        : AnyLayout(HStackLayout(alignment: .top, spacing: 12))
                    headerLayout {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(isActive ? "Amendment leg active" : "Ready to start amendment leg")
                                .font(.title2.scaled(by: 1.2).bold())
                                .accessibilityAddTraits(.isHeader)
                                .accessibilityIdentifier("amendment-leg-state")
                            if isActive {
                                Text(routeName).font(.subheadline).foregroundStyle(.secondary)
                            } else {
                                Text("\(routeName) · Manual progression")
                                    .font(.subheadline).foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        recordingStatus()
                    }
                    metrics
                    if legIndex == 0 {
                        Text(immediateDeparture
                             ? "Started from the selected departure point."
                             : "Departure point reported reached.")
                            .font(.subheadline.weight(.medium))
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(departureNoticeColor, in: .rect(cornerRadius: 12))
                            .accessibilityIdentifier("amendment-departure-notice")
                    }
                    if isActive { cues }
                    if singleColumn && isActive {
                        positionControl()
                        let layout = dynamicTypeSize.isAccessibilitySize
                            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
                            : AnyLayout(HStackLayout(spacing: 12))
                        layout { secondaryActions() }
                    }
                }
            }
            .scrollBounceBehavior(.basedOnSize)

            Group {
                if singleColumn {
                    primaryAction()
                } else {
                    HStack(spacing: 12) {
                        positionControl()
                        Spacer(minLength: 0)
                        secondaryActions()
                        primaryAction()
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.bottom, singleColumn ? 0 : 30)
        }
        .padding(.horizontal, singleColumn ? 14 : 20)
        .padding(.vertical, 18)
        .background(Color(.systemBackground))
    }

    private var departureNoticeColor: Color {
        colorScheme == .dark ? Color.mint.opacity(0.18)
            : Color(red: 225.0 / 255, green: 242.0 / 255, blue: 236.0 / 255)
    }

    @ViewBuilder
    private var metrics: some View {
        if isActive {
            if compact && !dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: 8) {
                    HStack(alignment: .top, spacing: 8) {
                        headingCard
                        timerCard
                    }
                    card("Planned flight time", value: flightTime, id: "amendment-flight-time")
                }
            } else {
                let layout = singleColumn ? AnyLayout(VStackLayout(spacing: 8))
                    : AnyLayout(HStackLayout(spacing: 16))
                layout {
                    headingCard
                    timerCard
                    card("Planned flight time", value: flightTime, id: "amendment-flight-time")
                }
            }
        } else {
            let layout = dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 8))
                : AnyLayout(HStackLayout(alignment: .top, spacing: singleColumn ? 8 : 16))
            layout {
                card("Heading", value: String(localized: "\(heading) magnetic"), id: "cockpit-heading")
                card("Flight time", value: String(localized: "\(flightTime) · Timer starts when you start the leg"), id: "amendment-flight-time")
            }
        }
    }

    private var headingCard: some View {
        Button(action: onEditHeading) {
            card("Operational heading", value: String(localized: "\(heading) magnetic"), id: "cockpit-heading")
        }
        .buttonStyle(.plain)
    }

    private var timerCard: some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            let elapsed = startedAt.map { max(0, Int(timeline.date.timeIntervalSince($0))) } ?? 0
            let text = AviationMapSymbology.formatDuration(elapsed)
            card("Leg timer", value: String(localized: "\(text) elapsed"), id: "cockpit-timer")
        }
    }

    private var cues: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("Leg-start cues").font(.subheadline.weight(.semibold))
            let altitude = altitudeFeet.formatted(.number.precision(.fractionLength(0)))
            if let frequencyMHz {
                let frequency = frequencyMHz.formatted(.number.precision(.fractionLength(2...3)))
                Text("\(altitude) ft MSL · \(frequency) MHz")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                Text("\(altitude) ft MSL")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            if let visualReference {
                Text(visualReference).font(.footnote).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 43, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color(.secondarySystemBackground), in: .rect(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("amendment-leg-start-cues")
    }

    private func card(_ title: LocalizedStringKey, value: String, id: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.subheadline.weight(.semibold))
            Text(value)
                .font(.footnote.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: isActive && !singleColumn ? 51 : 43, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color(.secondarySystemBackground), in: .rect(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(id)
    }
}
