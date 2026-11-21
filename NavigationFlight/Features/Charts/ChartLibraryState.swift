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
}
