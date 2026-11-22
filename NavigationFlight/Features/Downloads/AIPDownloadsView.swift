import SwiftUI

struct AIPDownloadsView: View {
    let updates: AIPChartUpdates
    let onBack: () -> Void
    let onOpenCharts: () -> Void
    @State private var confirmation: AIPChartUpdates.Offer?
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var typeSize

    private var compact: Bool { horizontalSizeClass == .compact || typeSize.isAccessibilitySize }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    card
                    if status.note == nil, updates.offer != nil, updates.transfer == .idle,
                       updates.discovery == .current {
                        Text(offlineAvailability)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: 690, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
            }
            .navigationTitle("Downloads")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: onBack) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.backward").accessibilityHidden(true)
                            Text("More")
                        }
                    }
                    .accessibilityIdentifier("downloads-back")
                }
            }
        }
        .task { updates.refresh(force: true) }
        .onChange(of: status.label) { _, label in
            if UIAccessibility.isVoiceOverRunning {
                AccessibilityNotification.Announcement(label).post()
            }
        }
        .alert("Download chart update?", isPresented: confirmationShown, presenting: confirmation) { offer in
            Button("Cancel", role: .cancel) { confirmation = nil }
            Button("Download") { updates.confirm(offer) }
        } message: { offer in
            Text("Download edition \(offer.amendment) (\(size(offer.totalPdfBytes))) for offline use.")
        }
    }

    private var confirmationShown: Binding<Bool> {
        Binding(get: { confirmation != nil }, set: { if !$0 { confirmation = nil } })
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 12) {
            if compact {
                VStack(alignment: .leading, spacing: 4) {
                    heading
                    statusLabel
                }
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 16) {
                    heading
                    Spacer(minLength: 0)
                    statusLabel
                }
            }
            Divider().accessibilityHidden(true)
            if compact {
                editions
                action
            } else {
                HStack(alignment: .center, spacing: 24) {
                    editions
                    Spacer(minLength: 0)
                    action
                }
            }
            if let note = status.note {
                Text(note)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            activity
        }
        .padding(16)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private var heading: some View {
        Text("Israel AIP charts")
            .font(.headline)
            .accessibilityAddTraits(.isHeader)
    }

    private var statusLabel: some View {
        Text(status.label)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(status.color)
            .accessibilityIdentifier("downloads-status")
    }

    private var displayOffer: AIPChartUpdates.Offer? {
        switch updates.transfer {
        case .downloading(let offer, _), .verifying(let offer): offer
        default: updates.offer
        }
    }

    private var editions: some View {
        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 5) {
            edition("Installed edition", updates.installed?.catalog.snapshot.amendment ?? "None")
            if let offer = displayOffer {
                edition(updates.discovery == .failed && updates.transfer == .idle ? "Last seen edition" : "Available edition", offer.amendment)
                if !updates.transfer.isRunning { edition("Download size", size(offer.totalPdfBytes)) }
            }
        }
        .frame(maxWidth: compact ? .infinity : 286, alignment: .leading)
        .font(.subheadline)
    }

    private func edition(_ name: String, _ value: String) -> some View {
        GridRow(alignment: .firstTextBaseline) {
            Text(name).foregroundStyle(.secondary)
            Spacer(minLength: 0).accessibilityHidden(true)
            Text(value).gridColumnAlignment(.trailing).fontWeight(.medium)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(name)
        .accessibilityValue(value)
    }

    @ViewBuilder private var activity: some View {
        if case let .downloading(offer, received) = updates.transfer {
            ProgressView(value: Double(received), total: Double(offer.totalPdfBytes)) {
                Text("\(size(received)) of \(size(offer.totalPdfBytes))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .accessibilityLabel("Chart download progress")
            .accessibilityValue("\(min(100, received * 100 / offer.totalPdfBytes)) percent")
        } else if updates.discovery == .checking && !updates.transfer.isRunning || isVerifying {
            ProgressView()
                .accessibilityLabel(status.label)
        }
    }

    private var isVerifying: Bool {
        if case .verifying = updates.transfer { return true }
        return false
    }

    @ViewBuilder private var action: some View {
        if case .downloading = updates.transfer {
            secondaryButton("Cancel download", id: "downloads-cancel") { updates.cancel() }
        } else if !isVerifying {
            if updates.transfer == .installed {
                secondaryButton("Open Charts", id: "downloads-open-charts", action: onOpenCharts)
            } else if updates.discovery == .failed && updates.transfer == .idle {
                secondaryButton("Check again", id: "downloads-check") { updates.refresh(force: true) }
            } else if let offer = updates.offer, updates.discovery != .checking {
                let retry = updates.transfer == .failed || updates.transfer == .verificationFailed
                Button {
                    confirmation = offer
                } label: {
                    Text(retry ? "Retry download" : "Download update")
                        .frame(maxWidth: compact ? .infinity : nil)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .accessibilityIdentifier("downloads-confirm")
            } else if updates.discovery == .current {
                secondaryButton("Check again", id: "downloads-check") { updates.refresh(force: true) }
            }
        }
    }

    private func secondaryButton(_ title: String, id: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)
            .accessibilityIdentifier(id)
    }

    private var status: (label: String, color: Color, note: String?) {
        switch updates.transfer {
        case .downloading: return ("Downloading update", .blue, nil)
        case .verifying: return ("Verifying charts", .blue, nil)
        case .installed: return ("Update installed", .green, "The new edition opens the next time you visit Charts.")
        case .cancelled: return ("Download canceled", .blue, transferRecoveryNote)
        case .failed: return ("Download failed", .orange, transferRecoveryNote)
        case .verificationFailed: return ("Charts could not be verified", .orange, transferRecoveryNote)
        case .idle:
            switch updates.discovery {
            case .idle, .checking:
                return ("Checking for updates", .secondary, updates.offer == nil ? nil : "Last known update shown while checking.")
            case .failed:
                return ("Update status unavailable", .orange, "Couldn’t check for updates. \(offlineAvailability)")
            case .current:
                if updates.offer == nil, updates.installed == nil {
                    return ("No update available", .secondary, offlineAvailability)
                }
                return updates.offer == nil ? ("Up to date", .green, nil) : ("Update available", .blue, nil)
            }
        }
    }

    private var offlineAvailability: String {
        updates.installed == nil ? "No chart edition is available offline." : "Installed charts are available offline."
    }

    private var transferRecoveryNote: String {
        updates.installed == nil ? offlineAvailability : "The installed edition is still available offline."
    }

    private func size(_ bytes: Int) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }
}
