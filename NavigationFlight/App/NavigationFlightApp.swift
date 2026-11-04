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

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
