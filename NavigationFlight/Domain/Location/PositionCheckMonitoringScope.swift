nonisolated enum PositionCheckMonitoringScope {
    static func shouldMonitor(
        sectionSelected: Bool,
        cockpitPresented: Bool,
        hasFlight: Bool,
        sceneActive: Bool
    ) -> Bool {
        sectionSelected && cockpitPresented && hasFlight && sceneActive
    }
}
