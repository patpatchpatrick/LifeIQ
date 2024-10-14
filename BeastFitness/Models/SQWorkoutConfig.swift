//
//  SQWorkoutConfig.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 10/14/24.
//

import Foundation

final class SQWorkoutConfig {
    static let shared = SQWorkoutConfig()
    
    func unitFor(_ quantityTypeIdentifier: SQQuantityType) -> SQUnit? {
        switch quantityTypeIdentifier {
        case .distanceWalkingRunning, .distanceCycling:
            return .mile
        case .activeEnergyBurned:
            return .kilocalorie
        case .heartRate:
            return .countPerMinute
        }
    }
}
