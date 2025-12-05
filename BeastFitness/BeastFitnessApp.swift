//
//  BeastFitnessApp.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 9/25/24.
//

import SwiftUI
import SwiftData

@main
struct BeastFitnessApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            SQRootTabView(appState: .shared)
        }
        .modelContainer(for: [
            SQDailyCheckInEntity.self
        ])
    }
}
