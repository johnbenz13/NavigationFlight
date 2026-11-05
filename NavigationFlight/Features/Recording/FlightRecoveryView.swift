import SwiftUI

struct FlightRecoveryView: View {
    let state: FlightRecoveryState
    let onContinue: (UUID) -> Void
    let onEndIncomplete: (UUID) -> Void
    let onEndAll: () -> Void
    let onDismissUnavailable: () -> Void

    @State private var pendingEndCandidate: RecoveryCandidate?

    var body: some View {
        Group {
            switch state {
            case .loading:
                ProgressView("Checking saved Flights…")
            case .none:
                EmptyView()
            case .single(let candidate):
                recoverySurface(
                    title: "Continue your flight?",
                    message: "A recording from \(candidate.flightPlanTitle) is still active."
                ) {
                    checkpointCard(title: "CONTINUE AVAILABLE FOR") {
                        if let expiresAt = candidate.expiresAt {
                            TimelineView(.periodic(from: .now, by: 1)) { context in
                                Text(remainingTime(until: expiresAt, now: context.date))
                                    .font(.largeTitle.bold().monospacedDigit())
                                    .accessibilityLabel("Continue available for \(remainingTime(until: expiresAt, now: context.date))")
                            }
                        }
                        if let lastActivityAt = candidate.lastActivityAt {
                            Text("Last saved activity \(lastActivityAt.formatted(.relative(presentation: .named)))")
                        }
                    }
                } actions: {
                    primaryButton("Continue Flight") { onContinue(candidate.id) }
                    secondaryButton("End as Incomplete", role: .destructive) {
                        pendingEndCandidate = candidate
                    }
                }
                .task(id: candidate.id) {
                    guard let expiresAt = candidate.expiresAt else { return }
                    let delay = max(0, expiresAt.timeIntervalSinceNow)
                    try? await Task.sleep(for: .seconds(delay))
                    guard !Task.isCancelled else { return }
                    onContinue(candidate.id)
                }
            case .selectionRequired(let candidates):
                recoverySurface(
                    title: "Choose a flight to continue",
                    message: "\(candidates.count) recoverable flights were found."
                ) {
                    checkpointCard(title: "RECOVERABLE RECORDINGS") {
                        ForEach(candidates) { candidate in
                            Text("•  \(candidate.flightPlanTitle)")
                        }
                    }
                } actions: {
                    ForEach(Array(candidates.enumerated()), id: \.element.id) { index, candidate in
                        Button {
                            onContinue(candidate.id)
                        } label: {
                            Text(candidate.flightPlanTitle)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(index == 0 ? AnyRecoveryButtonStyle.prominent : .secondary)
                        .contextMenu {
                            Button("End as Incomplete", role: .destructive) {
                                pendingEndCandidate = candidate
                            }
                        }
                        .accessibilityAction(named: "End as Incomplete") {
                            pendingEndCandidate = candidate
                        }
                        .accessibilityHint("Continues this saved Flight. Actions include ending it as incomplete.")
                    }
                    secondaryButton("End All as Incomplete", role: .destructive, action: onEndAll)
                }
            case .reconciledExpired(let count):
                recoverySurface(
                    title: "Old Flights were saved",
                    message: "NavigationFlight safely closed \(count) interrupted \(count == 1 ? "Flight" : "Flights") outside the continuation window."
                ) {
                    checkpointCard(title: "RECONCILIATION COMPLETE") {
                        Text("No recorded evidence was deleted")
                        Text("Each Flight closed at its last saved activity")
                    }
                } actions: {
                    primaryButton("Review Flights", action: onDismissUnavailable)
                    secondaryButton("Continue to App", action: onDismissUnavailable)
                }
            case .unsupported:
                recoverySurface(
                    title: "Unsupported recording",
                    message: "This Flight was created by a newer app version."
                ) {
                    checkpointCard(title: "DURABLE CHECKPOINT") {
                        Text("The saved package is preserved")
                        Text("Continuation is unavailable")
                        Text("No recording data was removed")
                    }
                } actions: {
                    primaryButton("Keep in Flights", action: onDismissUnavailable)
                    secondaryButton("Start New Flight", action: onDismissUnavailable)
                }
            case .failure:
                recoverySurface(
                    title: "Recovery unavailable",
                    message: "This saved Flight could not be restored safely."
                ) {
                    checkpointCard(title: "RECORDING PRESERVED") {
                        Text("No package data was removed")
                        Text("The other app sections remain available")
                    }
                } actions: {
                    primaryButton("Continue to App", action: onDismissUnavailable)
                }
            }
        }
        .confirmationDialog(
            "End this Flight as incomplete?",
            isPresented: Binding(
                get: { pendingEndCandidate != nil },
                set: { if !$0 { pendingEndCandidate = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("End as Incomplete", role: .destructive) {
                guard let candidate = pendingEndCandidate else { return }
                pendingEndCandidate = nil
                onEndIncomplete(candidate.id)
            }
            Button("Cancel", role: .cancel) {
                pendingEndCandidate = nil
            }
        } message: {
            Text("The recording remains stored, but it can no longer be continued.")
        }
    }

    private func remainingTime(until expiration: Date, now: Date) -> String {
        let seconds = max(0, Int(expiration.timeIntervalSince(now).rounded(.up)))
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    private func recoverySurface<Content: View, Actions: View>(
        title: LocalizedStringKey,
        message: LocalizedStringKey,
        @ViewBuilder content: () -> Content,
        @ViewBuilder actions: () -> Actions
    ) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("NavigationFlight")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.top, 42)

                Text(title)
                    .font(.title2.bold())
                    .foregroundStyle(.primary)
                    .accessibilityAddTraits(.isHeader)
                    .padding(.top, 34)

                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.top, 12)

                content()
                    .padding(.top, 102)

                VStack(spacing: 16) {
                    actions()
                }
                .padding(.top, 48)
            }
            .frame(maxWidth: 342, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.bottom, 60)
            .frame(maxWidth: .infinity)
        }
        .background(Color(.secondarySystemBackground))
    }

    private func checkpointCard<Content: View>(
        title: LocalizedStringKey,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.caption2.bold())
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 0) {
                content()
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
            .padding(.top, 20)
        }
        .padding(20)
        .frame(maxWidth: .infinity, minHeight: 136, alignment: .topLeading)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(.separator), lineWidth: 0.5)
        }
    }

    private func primaryButton(_ title: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).frame(maxWidth: .infinity)
        }
        .buttonStyle(AnyRecoveryButtonStyle.prominent)
    }

    private func secondaryButton(
        _ title: LocalizedStringKey,
        role: ButtonRole? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(role: role, action: action) {
            Text(title).frame(maxWidth: .infinity)
        }
        .buttonStyle(AnyRecoveryButtonStyle.secondary)
    }
}

private struct AnyRecoveryButtonStyle: ButtonStyle {
    enum Kind {
        case prominent
        case secondary
    }

    static let prominent = AnyRecoveryButtonStyle(kind: .prominent)
    static let secondary = AnyRecoveryButtonStyle(kind: .secondary)

    let kind: Kind

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(kind == .prominent ? Color.white : Color.primary)
            .frame(minHeight: 50)
            .background(
                kind == .prominent ? Color.accentColor : Color(.quaternarySystemFill),
                in: RoundedRectangle(cornerRadius: 14)
            )
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}
