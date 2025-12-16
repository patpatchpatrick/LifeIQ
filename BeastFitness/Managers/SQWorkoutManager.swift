//
//  SQWorkoutManager.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 12/13/25.
//

import SwiftData
import Foundation
import HealthKit

protocol SQWorkoutManaging {
    func saveWorkout(workout: SQWorkoutSessionable, to modelContext: ModelContext) async throws
    func getWorkout(withHkWorkoutId hkWorkoutId: String?, workoutSource: SQWorkoutSource, modelContext: ModelContext) throws -> SQWorkoutSessionable?
    func getWorkouts(for timeRange: SQTimeRange, modelContext: ModelContext) async throws -> [SQWorkoutSessionable]
}

final class SQWorkoutManager: SQWorkoutManaging {
    private let workoutService: SQWorkoutServicing.Type
    private let healthKitManager: SQHealthKitManaging
    
    init(workoutService: SQWorkoutServicing.Type = SQWorkoutService.self, healthKitManager: SQHealthKitManaging = SQHealthKitManager.shared) {
        self.workoutService = workoutService
        self.healthKitManager = healthKitManager
    }
    
    func getWorkouts(for timeRange: SQTimeRange, modelContext: ModelContext) async throws -> [any SQWorkoutSessionable] {
        let healthKitWorkouts = try await SQHealthKitManager.shared.fetchWorkouts(timeRange)
        // TODO: - Fetch manual workouts within the same time range and de-dup
        
        // TODO: - PTD Update this system to gracefully handle errors and properly sync with cloud
        var allWorkouts = [SQWorkoutSessionable]()
        for hkWorkout in healthKitWorkouts {
            do {
                let savedWorkout = try getWorkout(withHkWorkoutId: hkWorkout.uuid.uuidString, workoutSource: .hkWorkout(.init(hkWorkout: hkWorkout)), modelContext: modelContext)
                
                if let savedWorkout {
                    allWorkouts.append(savedWorkout)
                } else {
                    let workoutSource = SQWorkoutSource.hkWorkout(.init(hkWorkout: hkWorkout))
                    allWorkouts.append(SQWorkoutSession(workoutSource: workoutSource, overrideData: nil, hkWorkoutId: nil))
                }
                
            } catch {
                let workoutSource = SQWorkoutSource.hkWorkout(.init(hkWorkout: hkWorkout))
                allWorkouts.append(SQWorkoutSession(workoutSource: workoutSource, overrideData: nil, hkWorkoutId: nil))
            }
        }
        
        return allWorkouts
    }
    
    func saveWorkout(workout: SQWorkoutSessionable, to modelContext: ModelContext) async throws {
        
        /// If the workout doesn't have a health kit ID, let's attempt to save it to healthKit
        if workout.hkWorkoutId == nil {
            do {
                SQLogger.shared.log("Attempting to save workout to HealthKit", .debug, context: .healthKit)
                // TODO: - PTD do we want to always require workouts to be saved to healthkit?
                let hkWorkout = try await healthKitManager.saveWorkout(workout: workout)
                /// Set the ID on the workout so that it can be referenced from SwiftData using the hkWorkoutId
                workout.updateHkWorkoutId(hkWorkout?.uuid.uuidString)
                
            } catch {
                throw SQStandardError.standard(withDescription: "Could not save workout to HealthKit due to error: \(error.localizedDescription).")
            }
        }
        
        do {
            try SQWorkoutSessionEntity.upsert(session: workout, in: modelContext)
        } catch {
            SQLogger.shared.log(
                "Saving workout to SwiftData failed: \(error)",
                .error,
                context: .workoutSession
            )
            // TODO: PTD Error - throw check in error here and don't let the user continue to save to Firebase
        }
        
        do {
            try await workoutService.saveWorkout(workout)
        } catch {
            SQLogger.shared.log("Saving workout failed with error: \(error)", .debug, context: .workoutSession)
            // TODO: PTD Error - throw check in error here and let the user know that failed to save to cloud... add a system to retry saving all failed daily check ins in the background in the future.
        }
    }
    
    func getWorkout(withHkWorkoutId hkWorkoutId: String?, workoutSource: SQWorkoutSource, modelContext: ModelContext) throws -> (any SQWorkoutSessionable)? {
        return try SQWorkoutSessionEntity.getFromHkWorkout(source: workoutSource, hkWorkoutId: hkWorkoutId, context: modelContext)
    }
}
