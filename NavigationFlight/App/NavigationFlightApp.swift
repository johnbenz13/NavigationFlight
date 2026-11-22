//
//  NavigationFlightApp.swift
//  NavigationFlight
//
//  Created by Jonathan Bensaid on 10/10/2026.
//

import SwiftUI
import UIKit

@MainActor
final class NavigationFlightAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
#if DEBUG && targetEnvironment(simulator)
        if ChartSnapshotUITestFixture.blocksNetwork {
            precondition(URLProtocol.registerClass(ChartUITestOfflineProtocol.self))
        }
#endif
#if DEBUG
        guard ProcessInfo.processInfo.environment["NAVIGATION_FLIGHT_UI_TEST_LIBRARY_ID"] == nil else {
            return true
        }
#endif
        CoreLocationAircraftLocationSource.shared.resumeBackgroundActivityIfNeeded()
        return true
    }
}

@main
struct NavigationFlightApp: App {
    @UIApplicationDelegateAdaptor(NavigationFlightAppDelegate.self) private var appDelegate

    @State private var settingsController = SettingsController(store: Self.settingsStore())
    @State private var chartSnapshotStore: ChartSnapshotStore
    @State private var chartUpdates: AIPChartUpdates

    init() {
        let directory = Self.chartSnapshotDirectory
        let holdVerification = Self.holdsChartVerificationForReview
        let store = ChartSnapshotStore(directory: directory, bundledResources: Self.bundledCharts(in: directory)) {
            if holdVerification { Thread.sleep(forTimeInterval: 7) }
        }
        _chartSnapshotStore = State(initialValue: store)
        _chartUpdates = State(initialValue: AIPChartUpdates(
            store: store,
            service: Self.chartDownloadService(),
            cache: directory.appending(path: "update-index.json")
        ))
    }

    private static var holdsChartVerificationForReview: Bool {
#if DEBUG && targetEnvironment(simulator)
        let environment = ProcessInfo.processInfo.environment
        return environment["NAVIGATION_FLIGHT_UI_TEST_LIBRARY_ID"] != nil
            && environment["NAVIGATION_FLIGHT_UI_TEST_DOWNLOADS"] == "held"
#else
        return false
#endif
    }

    private static func bundledCharts(in directory: URL) -> ChartResources {
#if DEBUG && targetEnvironment(simulator)
        let environment = ProcessInfo.processInfo.environment
        if environment["NAVIGATION_FLIGHT_UI_TEST_LIBRARY_ID"] != nil,
           environment["NAVIGATION_FLIGHT_UI_TEST_NO_BUNDLED_CHARTS"] == "1" {
            return ChartResources(bundleRoot: directory.appending(path: "missing-chart-bundle"))
        }
#endif
        return .bundled
    }

    private static func chartDownloadService() -> AIPChartDownloadService {
#if DEBUG && targetEnvironment(simulator)
        if let service = AIPChartDownloadFixture.service() { return service }
#endif
        return AIPChartDownloadService()
    }

    private static var chartSnapshotDirectory: URL {
#if DEBUG
        if let id = ProcessInfo.processInfo.environment["NAVIGATION_FLIGHT_UI_TEST_LIBRARY_ID"] {
            return URL.temporaryDirectory.appending(path: "\(id)-charts", directoryHint: .isDirectory)
        }
#endif
        return (FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL.temporaryDirectory).appending(path: "AIPChartSnapshots", directoryHint: .isDirectory)
    }

    private static func settingsStore() -> any SettingsStore {
        let directory: URL
#if DEBUG
        if let id = ProcessInfo.processInfo.environment["NAVIGATION_FLIGHT_UI_TEST_LIBRARY_ID"] {
            directory = URL.temporaryDirectory.appending(path: "\(id)-settings", directoryHint: .isDirectory)
        } else {
            directory = settingsDirectory
        }
        return DiskSettingsStore(directory: directory, failNextSaves: ProcessInfo.processInfo.environment["NAVIGATION_FLIGHT_UI_TEST_SETTINGS_FAILURE_ONCE"] == "1" ? 1 : 0, beforeWrite: { _ in
            if ProcessInfo.processInfo.environment["NAVIGATION_FLIGHT_UI_TEST_SETTINGS_FAILURE"] == "1" {
                throw CocoaError(.fileWriteNoPermission)
            }
        })
#else
        directory = settingsDirectory
        return DiskSettingsStore(directory: directory)
#endif
    }

    private static var settingsDirectory: URL {
        (FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL.temporaryDirectory).appending(path: "Settings", directoryHint: .isDirectory)
    }

    var body: some Scene {
        WindowGroup {
            RootView(settingsController: settingsController, chartSnapshotStore: chartSnapshotStore, chartUpdates: chartUpdates)
        }
    }
}
