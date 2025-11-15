//
//  HKWorkout+Extensions.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 10/7/24.
//

import HealthKit

extension HKWorkout {
    
    var caloriesBurned: Double? {
        sumOutputFor(.activeKilocaloriesBurned)
    }
    
    func sumOutputFor(_ quantityTypeIdentifier: SQQuantityType) -> Double? {
        switch self.workoutActivityType {
        default:
            guard let hkUnit = quantityTypeIdentifier.unit?.hkUnit,
                  let quantityTypeIdentifier = quantityTypeIdentifier.hkQuantityTypeIdentifier,
                  let quantityType: HKQuantityType = .quantityType(forIdentifier: quantityTypeIdentifier) else {
                return nil
            }
            return self.allStatistics[quantityType]?.sumQuantity()?.doubleValue(for: hkUnit)
        }
    }
    
    func avgOutputFor(_ quantityTypeIdentifier: SQQuantityType) -> Double? {
        switch self.workoutActivityType {
        default:
            guard let hkUnit = quantityTypeIdentifier.unit?.hkUnit,
                  let quantityTypeIdentifier = quantityTypeIdentifier.hkQuantityTypeIdentifier,
                  let quantityType: HKQuantityType = .quantityType(forIdentifier: quantityTypeIdentifier)
            else {
                return nil
            }
            return self.allStatistics[quantityType]?.averageQuantity()?.doubleValue(for: hkUnit)
        }
    }
    
    var duration: TimeInterval? {
        switch self.workoutActivityType {
        default:
            let quantityTypeIdsToCheck: [HKQuantityTypeIdentifier] = [.activeEnergyBurned, .distanceWalkingRunning, .distanceCycling]
            
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
