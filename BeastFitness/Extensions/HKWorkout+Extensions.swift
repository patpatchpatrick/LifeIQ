//
//  HKWorkout+Extensions.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 10/7/24.
//

import HealthKit

extension HKWorkout {
    
    // TODO: - PTD finish with all activities
    var coreOutputQuantityTypeId: HKQuantityTypeIdentifier? {
        switch self.workoutActivityType {
        case .running:
            return .distanceWalkingRunning
        case .cycling:
            return .distanceCycling
        case .pickleball:
            return .activeEnergyBurned
        default:
            return nil
        }
    }
    
    var coreOutputUnit: HKUnit? {
        guard let coreOutputQuantityTypeId else { return nil }
        return unitFor(coreOutputQuantityTypeId)
    }
    
    var caloriesBurned: Double? {
        sumOutputFor(.activeEnergyBurned)
    }
    
    func sumOutputFor(_ quantityTypeIdentifier: HKQuantityTypeIdentifier) -> Double? {
        switch self.workoutActivityType {
        default:
            guard let quantityType: HKQuantityType = .quantityType(forIdentifier: quantityTypeIdentifier), let unit = unitFor(quantityTypeIdentifier) else {
                return nil
            }
            return self.allStatistics[quantityType]?.sumQuantity()?.doubleValue(for: unit)
        }
    }
    
    func averageOutputFor(_ quantityTypeIdentifier: HKQuantityTypeIdentifier) -> Double? {
        switch self.workoutActivityType {
        default:
            guard let quantityType: HKQuantityType = .quantityType(forIdentifier: quantityTypeIdentifier), let unit = unitFor(quantityTypeIdentifier) else {
                return nil
            }
            return self.allStatistics[quantityType]?.averageQuantity()?.doubleValue(for: unit)
        }
    }
    
    func unitFor(_ quantityTypeIdentifier: HKQuantityTypeIdentifier) -> HKUnit? {
        switch quantityTypeIdentifier {
        case .activeEnergyBurned:
            return .kilocalorie()
        case .distanceWalkingRunning, .distanceCycling:
            return .mile()
        case .heartRate:
            return .count().unitDivided(by: .minute())
        default:
            return nil
        }
    }
    
    var duration: TimeInterval? {
        switch self.workoutActivityType {
        default:
            var quantityTypeIdsToCheck: [HKQuantityTypeIdentifier] = [.activeEnergyBurned, .distanceWalkingRunning, .distanceCycling]
            
            for quantityTypeId in quantityTypeIdsToCheck {
                guard let quantityType: HKQuantityType = .quantityType(forIdentifier: quantityTypeId) else {
                    continue
                }
                
                guard let startDate = self.allStatistics[quantityType]?.startDate, let endDate = self.allStatistics[quantityType]?.endDate else {
                    continue
                }
                
                return abs(endDate.distance(to: startDate))
            }
            
            return nil
        }
    }
}
