import PDFKit
import SwiftUI

struct ChartViewer: View {
    let selection: ChartSelection
    let catalog: ChartCatalog
    let resources: ChartResources
    let onBack: () -> Void

    @State private var document: PDFDocument?
    @State private var didFail = false
    @State private var pageNumber = 1
    @State private var zoomRequest: ChartPDFView.ZoomRequest?
    @AccessibilityFocusState private var titleFocused: Bool
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            Group {
                if let document {
                    ChartPDFView(document: document, request: zoomRequest)
                        .accessibilityIdentifier("charts-pdf")
                        .onReceive(NotificationCenter.default.publisher(for: .PDFViewPageChanged)) { notification in
                            if let view = notification.object as? PDFView, view.document === document,
                               let page = view.currentPage {
                                pageNumber = document.index(for: page) + 1
                            }
                        }
                } else if didFail {
                    unavailable
                } else {
                    ProgressView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.secondarySystemBackground))
            if let document {
                Divider()
                documentControls(pageCount: document.pageCount)
            }
        }
        .background(Color(.systemBackground))
        .accessibilityDefaultFocus($titleFocused, true)
        .task(id: selection.id) {
            document = nil
            didFail = false
            pageNumber = 1
            zoomRequest = nil
            await Task.yield()
            guard !Task.isCancelled else { return }
            let result = try? ChartPDFDocument.open(selection.chart, in: catalog, resources: resources)
            guard !Task.isCancelled else { return }
            document = result
            didFail = result == nil
        }
    }

    private var header: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                backButton
                    .fixedSize(horizontal: true, vertical: false)
                Spacer(minLength: 0)
                chartHeading
                    .fixedSize(horizontal: true, vertical: false)
                Spacer(minLength: 0)
                backButton
                    .fixedSize(horizontal: true, vertical: false)
                    .hidden()
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 8) {
                backButton
                chartHeading.frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    private var chartHeading: some View {
        VStack(spacing: 3) {
            Text(selection.chart.title)
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("charts-viewer-title")
                .accessibilityFocused($titleFocused)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .multilineTextAlignment(.center)
    }

    private var subtitle: String {
        let aerodrome = "\(selection.aerodrome.name) (\(selection.aerodrome.code))"
        guard let pageLabel = selection.chart.pageLabel else { return aerodrome }
        return "\(aerodrome) · \(pageLabel)"
    }

    private var backButton: some View {
        Button(action: onBack) {
            Label(selection.aerodrome.name, systemImage: "chevron.backward")
                .font(.subheadline.weight(.medium))
                .frame(minHeight: 30)
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.capsule)
        .accessibilityIdentifier("charts-viewer-back")
    }

    private var unavailable: some View {
        VStack(spacing: 12) {
            Text("Chart unavailable")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            Text("Couldn’t open \(selection.chart.title) for \(selection.aerodrome.name) (\(selection.aerodrome.code)). Choose another chart.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button(action: onBack) {
                Text("Back to charts")
                    .frame(minHeight: 36)
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)
            .accessibilityIdentifier("charts-error-back")
        }
        .multilineTextAlignment(.center)
        .padding(24)
        .frame(maxWidth: 470)
        .background(Color(.systemBackground), in: .rect(cornerRadius: 20))
        .padding(.horizontal, 20)
    }

    private func documentControls(pageCount: Int) -> some View {
        let showsPagePosition = pageCount > 1 || horizontalSizeClass == .regular
        return ViewThatFits(in: .horizontal) {
            HStack {
                sourceLink.fixedSize(horizontal: true, vertical: false)
                Spacer(minLength: 12)
                if showsPagePosition {
                    pagePosition(count: pageCount)
                    Spacer(minLength: 12)
                }
                zoomControls
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    sourceLink
                    Spacer()
                    if showsPagePosition { pagePosition(count: pageCount) }
                }
                zoomControls.frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
    }

    private var sourceLink: some View {
        let edition = selection.chart.edition
        let printedDate = edition.printedDate.flatMap { text -> String? in
            let input = Date.ISO8601FormatStyle().year().month().day().dateSeparator(.dash)
            let output = Date.FormatStyle(
                timeZone: TimeZone(secondsFromGMT: 0) ?? .current
            )
            return (try? input.parse(text))?.formatted(output.day().month(.abbreviated).year())
        }
        let designation = printedDate ?? edition.printedDate ?? edition.amendment
        return Link(destination: selection.chart.sourceUrl) {
            Text(designation.map { "Israel AIP · \($0)" } ?? "Israel AIP")
                .font(.footnote.weight(.medium))
                .frame(minHeight: 44)
        }
        .accessibilityIdentifier("charts-source")
    }

    private func pagePosition(count: Int) -> some View {
        Text("\(pageNumber) of \(count)")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .monospacedDigit()
            .accessibilityLabel("Page \(pageNumber) of \(count)")
    }

    private var zoomControls: some View {
        HStack(spacing: 0) {
            Button {
                zoomRequest = .init(zoom: .out)
            } label: {
                Image(systemName: "minus")
                    .frame(minWidth: 44, minHeight: 44)
            }
            .accessibilityLabel("Zoom out")

            Button {
                zoomRequest = .init(zoom: .fit)
            } label: {
                Text("Fit page").padding(.horizontal, 4).frame(minHeight: 44)
            }
            .accessibilityIdentifier("charts-fit-page")

            Button {
                zoomRequest = .init(zoom: .in)
            } label: {
                Image(systemName: "plus")
                    .frame(minWidth: 44, minHeight: 44)
            }
            .accessibilityLabel("Zoom in")
        }
        .fixedSize(horizontal: true, vertical: false)
        .font(.subheadline.weight(.medium))
        .buttonStyle(.plain)
        .foregroundStyle(Color.accentColor)
        .background(Color.accentColor.opacity(0.08), in: .capsule)
    }
}
