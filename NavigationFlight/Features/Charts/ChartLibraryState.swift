struct ChartLibraryState: Equatable, Sendable {
    var aerodromePath: [String] = []
    var presentedChartID: String?
    private(set) var returnFocusChartID: String?
    private var selectedChartID: String?

    mutating func showChart(_ id: String) {
        returnFocusChartID = nil
        selectedChartID = id
        presentedChartID = id
    }

    mutating func didDismissChart() {
        returnFocusChartID = selectedChartID
        selectedChartID = nil
    }

    mutating func reconcile(with catalog: ChartCatalog) {
        let aerodromes = Set(catalog.aerodromes.map(\.id))
        aerodromePath = Array(aerodromePath.prefix { aerodromes.contains($0) })
        if let id = returnFocusChartID, catalog.selection(for: id) == nil {
            returnFocusChartID = nil
        }
        if let id = selectedChartID, catalog.selection(for: id) == nil {
            selectedChartID = nil
        }
        if let id = presentedChartID, catalog.selection(for: id) == nil {
            presentedChartID = nil
        }
    }
}
