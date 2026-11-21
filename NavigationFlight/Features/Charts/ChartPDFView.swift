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
            if bounds.size != lastViewport, !bounds.isEmpty {
                lastViewport = bounds.size
                updateScaleLimits(refit: fitScale == 0 || abs(scaleFactor - fitScale) < 0.01)
            }
        }

        func fitPage() {
            let page = currentPage
            updateScaleLimits(refit: true)
            if let page { go(to: page) }
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
            let crop = page.bounds(for: displayBox)
            let quarterTurn = page.rotation % 180 != 0
            let width = quarterTurn ? crop.height : crop.width
            let height = quarterTurn ? crop.width : crop.height
            let margins = pageBreakMargins
            let availableWidth = bounds.width - margins.left - margins.right
            let availableHeight = bounds.height - margins.top - margins.bottom
            guard width > 0, height > 0, availableWidth > 0, availableHeight > 0 else { return }
            fitScale = min(availableWidth / width, availableHeight / height)
            maxScaleFactor = max(fitScale * 8, 4)
            minScaleFactor = fitScale
            if refit { scaleFactor = fitScale }
        }
    }
}
