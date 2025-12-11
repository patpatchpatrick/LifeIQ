//
//  SQWorkoutSession+Mocks.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 12/10/25.
//

import Foundation

extension [any SQWorkoutSessionable] {
    static var mock: [any SQWorkoutSessionable] {
        [SQWorkoutSession.mockRun, SQWorkoutSession.mockRun, SQWorkoutSession.mockRun]
    }
}

extension SQWorkoutSession {
    
    static let mockRun = SQWorkoutSession(id: UUID(), workoutSource: .manual(.mock), device: nil, activityType: .running, activeDuration: nil, startDate: .now, endDate: .now, totalCalories: nil, averageHeartRate: nil)
}
