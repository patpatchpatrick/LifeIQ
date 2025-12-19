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
            ContentView()
        }
    }
}

import WatchKit
import HealthKit

final class WatchAppDelegate: NSObject, WKApplicationDelegate {
    
    // Ensure this exact signature is used
    func handle(_ workoutConfiguration: HKWorkoutConfiguration) {
        print("PTD Handle Watch Workout Triggered")
        Task { @MainActor in
            SQWatchAppState.shared.lastLaunchMessage = "Launched via startWatchApp ✅"
            SQWatchWorkoutManager.shared.startWorkout(with: workoutConfiguration)
        }
    }
}

@MainActor @Observable
final class SQWatchAppState {
    static let shared = SQWatchAppState()
    var lastLaunchMessage: String = "Idle"
}


// Watch target
import Foundation
import HealthKit
import OSLog

@MainActor
final class SQWatchWorkoutManager: NSObject {
    static let shared = SQWatchWorkoutManager()

    private let log = Logger(subsystem: "BeastFitnessWatch", category: "workout")
    private let healthStore = HKHealthStore()

    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?

    func startWorkout(with config: HKWorkoutConfiguration) {
        print("PTD START WATCH WORKOUT")
        log.info("PTD Start Watch Workout")

        Task {
            do {
                try await ensureAuthorization()

                let session = try HKWorkoutSession(healthStore: healthStore, configuration: config)
                let builder = session.associatedWorkoutBuilder()

                session.delegate = self
                builder.delegate = self
                builder.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: config)

                self.session = session
                self.builder = builder

                let start = Date()
                session.startActivity(with: start)

                builder.beginCollection(withStart: start) { success, error in
                    if let error { self.log.error("beginCollection error: \(error.localizedDescription)") }
                    else { self.log.info("beginCollection success=\(success)") }
                }

                session.startMirroringToCompanionDevice { success, error in
                    if let error { self.log.error("startMirroring error: \(error.localizedDescription)") }
                    else { self.log.info("startMirroring success=\(success)") }
                }

            } catch {
                log.error("startWorkout failed: \(error.localizedDescription)")
            }
        }
    }

    private func ensureAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else { return }

        let hr = HKQuantityType.quantityType(forIdentifier: .heartRate)!
        let activeEnergy = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
        let workoutType = HKObjectType.workoutType()

        try await healthStore.requestAuthorization(
            toShare: [workoutType],
            read: [hr, activeEnergy]
        )

        log.info("✅ HealthKit authorization requested")
    }
}


extension SQWatchWorkoutManager: HKWorkoutSessionDelegate {
    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession,
                                    didChangeTo toState: HKWorkoutSessionState,
                                    from fromState: HKWorkoutSessionState,
                                    date: Date) {
        // handle pause/resume/end if you want
    }

    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        print("session error:", error)
    }
}

extension SQWatchWorkoutManager: HKLiveWorkoutBuilderDelegate {
    nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}

    nonisolated func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder,
                                    didCollectDataOf collectedTypes: Set<HKSampleType>) {
        // Heart rate updates arrive here via statistics
        let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
        if collectedTypes.contains(hrType),
           let stats = workoutBuilder.statistics(for: hrType),
           let quantity = stats.mostRecentQuantity() {

            let bpm = quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
            Task { @MainActor in
                // TODO: send bpm to phone (see step 4)
                print("HR:", bpm)
            }
        }
    }
}

