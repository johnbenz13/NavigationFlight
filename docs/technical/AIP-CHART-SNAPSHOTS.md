# Offline AIP chart snapshots

The app bundles a pinned chart edition as its offline fallback. A
`ChartSnapshot` combines the release pin, decoded catalog, and PDF root.
Keep the handle while a viewer is open so the catalog and its PDF files
always come from the same edition.

The app owns one `ChartSnapshotStore` actor. To install an edition, pass
`install(from:pin:)` a local directory containing `AIPCharts/index.json`
and `AIPCharts/pdf/`, plus the expected pin from the trusted release
metadata. The store validates the manifest and inventory, imports the files
into its own staging directory, checks the imported PDFs, and replaces the
receipt atomically. An error or cancellation before receipt replacement
leaves the last committed edition selected.

The receipt retains the current and prior verified downloads. On launch,
the store removes abandoned staging directories and editions outside that
receipt. Within a running process it keeps retired editions on disk so open
viewers can finish using them. Selection checks the current and prior
downloads and uses the newest valid edition among those and the bundled
snapshot. If a download is missing or corrupt, selection falls back to the
remaining valid edition.

The app selects a snapshot when it launches and refreshes the selection on
entry to Charts. A chart presentation carries the selected snapshot as
part of its value. When Charts adopts a new snapshot, it keeps the
aerodrome route and chart focus where the IDs still exist.

## Simulator verification

`ChartLibraryUITests` installs two distinguishable fixture PDFs through the
store in a disposable Simulator directory. The test backgrounds and
foregrounds the app while edition A is open. A test-only accessibility
value confirms that edition B committed before the test checks that the
viewer still shows A. The test then revisits Charts and relaunches the
app to verify B is selected.

The Debug Simulator harness installs a `URLProtocol` that rejects HTTP
and HTTPS requests made through `URLSession`. Each launch verifies that
an HTTP probe reaches the rejecting protocol before loading charts.
