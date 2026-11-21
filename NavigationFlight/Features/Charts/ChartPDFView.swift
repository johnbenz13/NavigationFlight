import PDFKit
import SwiftUI

struct ChartPDFView: UIViewRepresentable {
    enum Zoom {
        case out, fit, `in`
    }

    struct ZoomRequest: Identifiable {
        let id = UUID()
        let zoom: Zoom
    }

    let document: PDFDocument
    let request: ZoomRequest?

    func makeUIView(context: Context) -> DocumentView {
        let view = DocumentView()
        view.backgroundColor = .secondarySystemBackground
        view.displayBox = .cropBox
        view.displayMode = .singlePageContinuous
        view.displaysPageBreaks = true
        view.pageBreakMargins = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        view.document = document
        return view
    }

    func updateUIView(_ view: DocumentView, context: Context) {
        if view.document !== document {
            view.document = document
            view.fitPage()
        }
        if let request, request.id != view.lastRequestID {
            view.lastRequestID = request.id
            view.zoom(request.zoom)
        }
    }

    final class DocumentView: PDFView {
        var lastRequestID: UUID?
        private var lastViewport = CGSize.zero
        private var fitScale: CGFloat = 0

        override func layoutSubviews() {
            super.layoutSubviews()
            if bounds.size != lastViewport, bounds.width > 24, bounds.height > 24 {
                lastViewport = bounds.size
                updateScaleLimits(refit: fitScale == 0 || abs(scaleFactor - fitScale) < 0.01)
            }
        }

        func fitPage() {
            updateScaleLimits(refit: true)
            if let currentPage { go(to: currentPage) }
        }

        func zoom(_ command: Zoom) {
            switch command {
            case .out: scaleFactor = max(minScaleFactor, scaleFactor / 1.4)
            case .fit: fitPage()
            case .in: scaleFactor = min(maxScaleFactor, scaleFactor * 1.4)
            }
        }

        private func updateScaleLimits(refit: Bool) {
            guard let page = currentPage ?? document?.page(at: 0) else { return }
            let size = page.bounds(for: displayBox).size
            guard size.width > 0, size.height > 0, bounds.width > 24, bounds.height > 24 else { return }
            fitScale = min((bounds.width - 24) / size.width, (bounds.height - 24) / size.height)
            maxScaleFactor = max(fitScale * 8, 4)
            minScaleFactor = fitScale
            if refit { scaleFactor = fitScale }
        }
    }
}
