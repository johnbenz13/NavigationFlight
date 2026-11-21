import SwiftUI

struct ChartLibraryView: View {
    let catalog: ChartCatalog?
    @Binding var state: ChartLibraryState
    @AccessibilityFocusState private var focusedChart: String?
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        NavigationStack(path: $state.aerodromePath) {
            Group {
                if let catalog {
                    List {
                        ForEach(ChartCatalog.Group.allCases, id: \.self) { group in
                            Section(group.title) {
                                ForEach(catalog.aerodromes(in: group)) { aerodrome in
                                    NavigationLink(value: aerodrome.id) {
                                        chartListLabel(
                                            aerodrome.name, detail: aerodrome.code, icon: "arrow.up.circle"
                                        )
                                    }
                                    .accessibilityIdentifier("charts-aerodrome-\(aerodrome.id)")
                                    .listRowBackground(Color(.secondarySystemBackground))
                                }
                            }
                        }
                        sourceLink
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                    .contentMargins(.horizontal, listSideMargin, for: .scrollContent)
                } else {
                    ContentUnavailableView(
                        "Charts unavailable",
                        systemImage: "doc",
                        description: Text("The bundled Israel AIP catalog could not be opened.")
                    )
                }
            }
            .navigationTitle("Charts")
            .navigationDestination(for: String.self) { aerodromeID in
                if let aerodrome = catalog?.aerodromes.first(where: { $0.id == aerodromeID }) {
                    aerodromeCharts(aerodrome)
                }
            }
        }
        .onChange(of: state.presentedChartID) { _, id in
            if id != nil { focusedChart = nil }
        }
        .onChange(of: state.returnFocusChartID) { _, id in
            if let id, state.presentedChartID == nil { focusedChart = id }
        }
    }

    private func aerodromeCharts(_ aerodrome: ChartCatalog.Aerodrome) -> some View {
        List {
            Section {
                ForEach(aerodrome.charts) { chart in
                    Button {
                        state.showChart(chart.id)
                    } label: {
                        HStack {
                            chartListLabel(chart.title, detail: chart.pageLabel, icon: "document")
                            Spacer(minLength: 8)
                            Image(systemName: "chevron.forward")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.tertiary)
                                .accessibilityHidden(true)
                        }
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("charts-document-\(chart.id)")
                    .accessibilityFocused($focusedChart, equals: chart.id)
                    .listRowBackground(Color(.secondarySystemBackground))
                }
            } header: {
                VStack(alignment: .leading, spacing: 12) {
                    Text("\(aerodrome.code) · \(aerodrome.group.singularTitle)")
                    Text("Visual charts")
                }
                .textCase(nil)
            }
            sourceLink
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .contentMargins(.horizontal, listSideMargin, for: .scrollContent)
        .navigationTitle(aerodrome.name)
        .navigationBarTitleDisplayMode(.large)
    }

    private var listSideMargin: CGFloat? {
        horizontalSizeClass == .regular ? 52 : nil
    }

    private var sourceLink: some View {
        Section {
            Link("Israel AIP", destination: ChartCatalog.officialSource)
                .font(.footnote)
                .listRowBackground(Color.clear)
        }
    }

    private func chartListLabel(_ title: String, detail: String?, icon: String) -> some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)
                if let detail {
                    Text(detail)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        } icon: {
            Image(systemName: icon)
                .foregroundStyle(Color.accentColor)
                .accessibilityHidden(true)
        }
        .padding(.vertical, 5)
        .accessibilityElement(children: .combine)
    }
}
