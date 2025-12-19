//
//  Beast_Fitness_WatchApp.swift
//  Beast Fitness Watch Watch App
//
//  Created by Patrick Doyle on 12/18/25.
//

import SwiftUI

@main
struct Beast_Fitness_Watch_Watch_AppApp: App {
    @WKApplicationDelegateAdaptor(WatchAppDelegate.self) var delegate

    var body: some Scene {
        WindowGroup {
            SWRootView(appState: .shared)
        }
    }
}
