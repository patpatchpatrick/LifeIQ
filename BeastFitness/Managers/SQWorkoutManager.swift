//
//  SQWorkoutManager.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 12/13/25.
//

import SwiftData
import Foundation
import HealthKit
import BeastFitnessCore

protocol SQWorkoutManaging {
    func saveWorkout(workout: SQWorkoutSessionable, to modelContext: ModelContext) async throws
    func deleteWorkout(workout: SQWorkoutSessionable, from modelContext: ModelContext) async throws
    func deletionTypeForWorkout(_ workout: any SQWorkoutSessionable) -> SQWorkoutManager.WorkoutDeletionType
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
                    
                    allWorkouts.appendIfNotNil(safeguardedWorkout(workout: savedWorkout))
                    
                } else {
                    
                    let workoutSource = SQWorkoutSource.hkWorkout(.init(hkWorkout: hkWorkout))
                    let sqHkWorkout = SQWorkoutSession(workoutSource: workoutSource, overrideData: nil, hkWorkoutId: nil)
                    allWorkouts.appendIfNotNil(safeguardedWorkout(workout: sqHkWorkout))
                }
                
            } catch {
                
                let workoutSource = SQWorkoutSource.hkWorkout(.init(hkWorkout: hkWorkout))
                let sqHkWorkout = SQWorkoutSession(workoutSource: workoutSource, overrideData: nil, hkWorkoutId: nil)
                allWorkouts.appendIfNotNil(safeguardedWorkout(workout: sqHkWorkout))
            }
        }
        
        return allWorkouts
    }
    
    /// Checks if a workout can be shown
    private func safeguardedWorkout(workout: SQWorkoutSessionable) -> SQWorkoutSessionable? {
        guard !SQUserDefaults.shared.isWorkoutHidden(workout.workoutSource.sourcableData.sourceId) else {
            return nil
        }
        return workout
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
                throw SQError.standard(withDescription: "Could not save workout to HealthKit due to error: \(error.localizedDescription).")
            }
        }
        
        do {
            try SQWorkoutSessionEntity.upsert(session: workout, in: modelContext)
        } catch {
            SQLogger.shared.log(
                "Saving workout to SwiftData failed: \(error)",
                .error,
                context: .workoutManager
            )
            // TODO: PTD Error - throw check in error here and don't let the user continue to save to Firebase
        }
        
        do {
            try await workoutService.saveWorkout(workout)
        } catch {
            SQLogger.shared.log("Saving workout failed with error: \(error)", .debug, context: .workoutManager)
            // TODO: PTD Error - throw check in error here and let the user know that failed to save to cloud... add a system to retry saving all failed daily check ins in the background in the future.
        }
    }
    
    enum WorkoutDeletionType {
        case hiddenHealtKit
        case hiddenStrava
        case standard /// Deleted from data and HealthKit
    }
    
    func deletionTypeForWorkout(_ workout: any SQWorkoutSessionable) -> WorkoutDeletionType {
        switch workout.workoutSource {
        case .hkWorkout(let hkWorkout):
            let wasCreatedByThisApp = hkWorkout.hkWorkout.sourceRevision.source.bundleIdentifier == Bundle.main.bundleIdentifier
            
            /// Can only delete workouts in HealthKit that were created by this app
            return wasCreatedByThisApp ? .standard : .hiddenHealtKit
            
        case .stravaWorkout:
            return .hiddenStrava
            
        case .manual:
            return .standard
        }
    }
    
    private func attemptToDeleteWorkoutFromHealthKit(_ workout: SQWorkoutSessionable) async {
        if let healthKitId = workout.hkWorkoutId {
            do {
                try await healthKitManager.deleteWorkout(with: healthKitId)
                SQLogger.shared.log("Successfully deleted workout from HealthKit: \(workout.id)-\(workout.visibleTitle)", .info, context: .workoutManager)
            } catch {
                // TODO: - PTD if we can't delete workouts from healthkit, save the list of workouts we can't delete to SwiftData or Firestore so we can retry
                SQLogger.shared.log("Could not delete workout from HealthKit: \(error)", .error, context: .workoutManager)
            }
        }
    }
    
    func deleteWorkout(workout: any SQWorkoutSessionable, from modelContext: ModelContext) async throws {
        
        let deletionType = deletionTypeForWorkout(workout)
        
        switch deletionType {
        case .hiddenHealtKit, .hiddenStrava:
            SQLogger.shared.log("Hiding workout: \(workout.id)-\(workout.visibleTitle)", .info, context: .workoutManager)
            /// Always hide the workout using the source ID. Because this is the ID we have when querying workouts.
            SQUserDefaults.shared.hideWorkout(workout.workoutSource.sourcableData.sourceId)
            
        case .standard:
            await attemptToDeleteWorkoutFromHealthKit(workout)
            
        }
        
        do {
            // TODO: - Update to use soft deletion, and run a job to delete workouts from Firestore regularly
            try SQWorkoutSessionEntity.delete(workoutSession: workout, in: modelContext, mode: .hard)
            SQLogger.shared.log("Successfully deleted workout from SwiftData: \(workout.id)-\(workout.visibleTitle)", .info, context: .workoutManager)
        } catch {
            SQLogger.shared.log("Could not delete workout from SwiftData: \(error)", .error, context: .workoutManager)
        }
    }
    
    func getWorkout(withHkWorkoutId hkWorkoutId: String?, workoutSource: SQWorkoutSource, modelContext: ModelContext) throws -> (any SQWorkoutSessionable)? {
        return try SQWorkoutSessionEntity.getFromHkWorkout(source: workoutSource, hkWorkoutId: hkWorkoutId, context: modelContext)
    }
}
