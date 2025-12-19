//
//  SQWatchInterface.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 12/18/25.
//

import HealthKit
import BeastFitnessCore

final class SQWatchInterface: NSObject {
    private let healthStore = HKHealthStore()
    
    static let shared = SQWatchInterface()
    private var activeBuilder: HKLiveWorkoutBuilder?
    private var activeWorkoutSession: HKWorkoutSession?

    func startStrengthWorkoutOnWatch() {
        var config = HKWorkoutConfiguration()
        config.activityType = .functionalStrengthTraining
        config.locationType = .indoor

        healthStore.startWatchApp(with: config) { success, error in
            if let error { print("startWatchApp error:", error) }
            print("startWatchApp success:", success)
        }
    }
    
    func configureMirroringHandler(
            onStart: @escaping @MainActor (HKWorkoutSession) -> Void
        ) {
            
            SQLogger.shared.log("Starting Watch Mirror Handler", .debug, context: .watchInterface)
            healthStore.workoutSessionMirroringStartHandler = { mirroredSession in
                SQLogger.shared.log("Received mirrored session: \(mirroredSession.activityType)", .debug, context: .watchInterface)
                        // Set the delegate for the session
                        mirroredSession.delegate = self
                        
                        // Access the builder.
                        // If the compiler complains about the session property,
                        // ensure the mirroredSession is explicitly cast or handled:
                        let builder = mirroredSession.associatedWorkoutBuilder()
                        builder.delegate = self
                self.activeBuilder = builder
                self.activeWorkoutSession = mirroredSession
                
                // 🔥 Important: start collection on the mirrored builder
                        let start = Date() // or if you can derive the real start later, use that
                        builder.beginCollection(withStart: start) { success, error in
                            if let error {
                                print("iPhone beginCollection error:", error)
                            } else {
                                print("iPhone beginCollection success:", success)
                            }
                        }
                        
                    }
        }
}

extension SQWatchInterface: HKWorkoutSessionDelegate {
    
    func workoutSession(_ workoutSession: HKWorkoutSession,
                        didUpdateHealthLevel workoutConfiguration: HKWorkoutConfiguration) {
        // Handle config changes if needed
    }

    func workoutSession(_ workoutSession: HKWorkoutSession,
                        didChangeTo toState: HKWorkoutSessionState,
                        from fromState: HKWorkoutSessionState,
                        date: Date) {
        print("Mirrored session state changed to: \(toState.rawValue)")
    }

    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        print("Mirroring error: \(error.localizedDescription)")
    }

    // THIS IS THE KEY: Receiving the mirrored data
    func workoutSession(_ workoutSession: HKWorkoutSession,
                        didDisconnectFromRemoteDeviceWithError error: Error?) {
        // Clean up UI
    }
    
    // Note: On iOS 17+, mirrored data often flows through the
    // HKWorkoutSession's associated builder if you need statistics.
}

extension SQWatchInterface: HKLiveWorkoutBuilderDelegate {
    
    func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        print("📱 didCollectDataOf:", collectedTypes)

        let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
        if collectedTypes.contains(hrType),
           let stats = workoutBuilder.statistics(for: hrType),
           let q = stats.mostRecentQuantity() {

            let bpm = q.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
            print("📱 iPhone HR:", bpm)
        } else {
            print("📱 no HR in collected types yet")
        }
    }
    
    func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {
        print("PTD Did collect event", workoutBuilder)
    }
}
