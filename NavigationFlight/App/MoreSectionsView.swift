import SwiftUI

struct MoreSectionsView: View {
    let hasUpdate: Bool
    let onDownloads: () -> Void
    let onSettings: () -> Void

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        NavigationStack {
            List {
                Section {
                    row("Downloads", icon: "arrow.down.circle", id: "more-downloads", pending: hasUpdate, action: onDownloads)
                    row("Settings", icon: "gearshape", id: "more-settings", action: onSettings)
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .contentMargins(.horizontal, horizontalSizeClass == .regular ? 52 : nil, for: .scrollContent)
            .navigationTitle("More")
        }
    }

    private func row(_ title: String, icon: String, id: String, pending: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    Label {
                        Text(title)
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    } icon: {
                        Image(systemName: icon).foregroundStyle(.tint)
                    }
                    if pending && typeSize.isAccessibilitySize { updateLabel }
                }
                Spacer(minLength: 4)
                if pending && !typeSize.isAccessibilitySize { updateLabel }
                Image(systemName: "chevron.forward")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityValue(pending ? "Update available" : "")
        .accessibilityIdentifier(id)
        .listRowBackground(Color(.secondarySystemBackground))
    }

    private var updateLabel: some View {
        Label("Update available", systemImage: "circle.fill")
            .labelStyle(UpdateLabelStyle())
            .font(.caption.weight(.medium))
            .foregroundStyle(.tint)
            .fixedSize(horizontal: false, vertical: true)
    }

    private struct UpdateLabelStyle: LabelStyle {
        func makeBody(configuration: Configuration) -> some View {
            HStack(spacing: 5) {
                configuration.icon.font(.system(size: 6)).foregroundStyle(.red).accessibilityHidden(true)
                configuration.title
            }
        }
    }
}
