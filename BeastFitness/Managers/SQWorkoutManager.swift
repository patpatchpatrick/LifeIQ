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
    func getWorkout(id: UUID, workoutSource: SQWorkoutSource, modelContext: ModelContext) throws -> SQWorkoutSessionable?
}

final class SQWorkoutManager: SQWorkoutManaging {
    private let workoutService: SQWorkoutServicing.Type
    
    init(workoutService: SQWorkoutServicing.Type = SQWorkoutService.self) {
        self.workoutService = workoutService
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
    
    func getWorkout(id: UUID, workoutSource: SQWorkoutSource, modelContext: ModelContext) throws -> (any SQWorkoutSessionable)? {
        return try SQWorkoutSessionEntity.get(id: id, context: modelContext, workoutSource: workoutSource)
    }
}
