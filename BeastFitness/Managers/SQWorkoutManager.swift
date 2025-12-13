//
//  SQWorkoutManager.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 12/13/25.
//

import SwiftData
import Foundation

protocol SQWorkoutManaging {
    func saveWorkout(workout: SQWorkoutSessionable, to modelContext: ModelContext) async throws
    func getWorkout(id: String, workoutSource: SQWorkoutSource, modelContext: ModelContext) throws -> SQWorkoutSessionable?
    func getWorkouts(for timeRange: SQTimeRange, modelContext: ModelContext) async throws -> [SQWorkoutSessionable]
}

final class SQWorkoutManager: SQWorkoutManaging {
    private let workoutService: SQWorkoutServicing.Type
    
    init(workoutService: SQWorkoutServicing.Type = SQWorkoutService.self) {
        self.workoutService = workoutService
    }
    
    func getWorkouts(for timeRange: SQTimeRange, modelContext: ModelContext) async throws -> [any SQWorkoutSessionable] {
        let healthKitWorkouts = try await SQHealthKitManager.shared.fetchWorkouts(timeRange)
        
        // TODO: - PTD Update this system to gracefully handle errors and properly sync with cloud
        var allWorkouts = [SQWorkoutSessionable]()
        for hkWorkout in healthKitWorkouts {
            do {
                print("PTD HK Workout Id", hkWorkout.uuid.uuidString)
                let savedWorkout = try getWorkout(id: hkWorkout.uuid.uuidString, workoutSource: .hkWorkout(.init(hkWorkout: hkWorkout)), modelContext: modelContext)
                print("PTD Get workout successful", savedWorkout == nil)
                if let savedWorkout {
                    print("PTD Get workout non-nil, appending saved workout", savedWorkout)
                    allWorkouts.append(savedWorkout)
                } else {
                    allWorkouts.append(SQWorkoutSource.hkWorkout(.init(hkWorkout: hkWorkout)).buildWorkout())
                }
            } catch {
                print("PTD Get workout failed, appending hk workout")
                allWorkouts.append(SQWorkoutSource.hkWorkout(.init(hkWorkout: hkWorkout)).buildWorkout())
            }
        }
        
        return allWorkouts
    }
    
    func saveWorkout(workout: SQWorkoutSessionable, to modelContext: ModelContext) async throws {
        
        do {
            print("PTD attempt save workout Swift Data")
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
    
    func getWorkout(id: String, workoutSource: SQWorkoutSource, modelContext: ModelContext) throws -> (any SQWorkoutSessionable)? {
        return try SQWorkoutSessionEntity.get(id: id, context: modelContext, workoutSource: workoutSource)
    }
}
