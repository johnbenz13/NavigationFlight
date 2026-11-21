import SwiftUI

struct CockpitChartsPanel: View {
    let list: CockpitChartList?
    let returnFocus: String?
    let onOpen: (String) -> Void
    let onClose: () -> Void
    @AccessibilityFocusState private var focusedRow: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Charts")
                    .font(.title2.bold())
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("cockpit-charts-title")
                Spacer(minLength: 12)
                Button(action: onClose) {
                    Text("Close")
                        .font(.subheadline.weight(.semibold))
                        .frame(minWidth: 48, minHeight: 48)
                        .contentShape(.rect)
                }
                .accessibilityIdentifier("close-cockpit-charts")
            }
            ScrollViewReader { scroll in
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        if let list {
                            chartGroups(list)
                        } else {
                            notice("Charts unavailable", detail: "The bundled Israel AIP catalog could not be opened.")
                        }
                        Link("Israel AIP", destination: ChartCatalog.officialSource)
                            .font(.footnote.weight(.medium))
                            .padding(.vertical, 5)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .accessibilityIdentifier("cockpit-charts-scroll")
                .task(id: returnFocus) {
                    if let returnFocus {
                        scroll.scrollTo(returnFocus, anchor: .center)
                        focusedRow = returnFocus
                    }
                }
            }
        }
        .padding(22)
        .background(Color(.systemBackground))
        .accessibilityElement(children: .contain)
        .accessibilityDefaultFocus($focusedRow, returnFocus)
    }

    @ViewBuilder
    private func chartGroups(_ list: CockpitChartList) -> some View {
        if list.notices.count == 2, list.notices.allSatisfy({ $0.reason == .unspecified }) {
            notice("No charts for this Flight", detail: "The loaded Flight Plan does not specify a departure or arrival aerodrome.")
        } else {
            ForEach(list.notices) { item in
                notice(item.title, detail: item.detail)
            }
        }
        ForEach(list.groups) { group in
            VStack(alignment: .leading, spacing: 5) {
                Text(group.tier.rawValue)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.secondary)
                    .accessibilityAddTraits(.isHeader)
                VStack(spacing: 0) {
                    ForEach(group.rows) { row in
                        if row.id != group.rows.first?.id {
                            Divider().padding(.leading, 40)
                        }
                        chartRow(row).id(row.id)
                    }
                }
                .background(Color(.secondarySystemBackground), in: .rect(cornerRadius: 12))
            }
        }
    }

    private func chartRow(_ row: CockpitChartList.Row) -> some View {
        Button {
            onOpen(row.id)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "document")
                    .foregroundStyle(Color.accentColor)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(row.selection.chart.title)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                    Text(row.context)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 4)
                Image(systemName: "chevron.forward")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(minHeight: 44)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("cockpit-chart-\(row.id)")
        .accessibilityFocused($focusedRow, equals: row.id)
    }

    private func notice(_ title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.subheadline.weight(.semibold))
            Text(detail)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(.secondarySystemBackground), in: .rect(cornerRadius: 12))
        .accessibilityElement(children: .combine)
    }
}
