import Testing
@testable import NavigationFlight

@Suite("Position Check monitoring scope")
struct PositionCheckMonitoringScopeTests {
    @Test("Monitoring requires every active cockpit condition", arguments: [
        (true, true, true, true, true),
        (false, true, true, true, false),
        (true, false, true, true, false),
        (true, true, false, true, false),
        (true, true, true, false, false)
    ])
    func monitoringConditions(
        sectionSelected: Bool,
        cockpitPresented: Bool,
        hasFlight: Bool,
        sceneActive: Bool,
        expected: Bool
    ) {
        #expect(PositionCheckMonitoringScope.shouldMonitor(
            sectionSelected: sectionSelected,
            cockpitPresented: cockpitPresented,
            hasFlight: hasFlight,
            sceneActive: sceneActive
        ) == expected)
    }
}
