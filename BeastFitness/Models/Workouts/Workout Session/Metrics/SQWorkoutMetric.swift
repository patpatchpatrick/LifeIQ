//
//  SQWorkoutMetric.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 12/15/25.
//

struct SQWorkoutMetric: Codable {
    let quantityType: SQQuantityType
    let displayName: String
    let unit: SQUnit
    let value: Double
    
    var outputAndUnitString: String {
        "\(displayableValue(for: quantityType, value: value)) \(unit.unitString ?? "")"
    }
    
    func displayableValue(for quantityType: SQQuantityType, value: Double) -> String {
        switch quantityType {
            
        case .distanceWalkingRunning, .distanceCycling, .distanceSwimming, .distanceRowing, .distanceDownhillSnowSports, .distanceCrossCountrySkiing, .flightsClimbed, .activeKilocaloriesBurned, .heartRate, .sqTotalVolumeLifted, .unknown:
            return value.sqShortString
            
        case .sqPaceRunning:
            return value.timeCode() /// eg 7:43
        }
    }
}

// MARK: - SQWorkoutSession Build Metrics

extension SQWorkoutSession {
    
    static func getMetric(for quantityType: SQQuantityType, workoutSource: SQWorkoutSource) -> SQWorkoutMetric? {
        guard let unit = quantityType.unit
        else {
            return nil
        }
        
        switch quantityType.outputCalculationType {
        case .sum:
            
            guard let output = workoutSource.sourcableData.sumOutputFor(quantityType) else { return nil }
            
            return .init(
                quantityType: quantityType,
                displayName: quantityType.displayTitle,
                unit: unit,
                value: output)
            
        case .average:
            
            guard let output = workoutSource.sourcableData.avgOutputFor(quantityType) else { return nil }
            
            return .init(
                quantityType: quantityType,
                displayName: quantityType.displayTitle,
                unit: unit,
                value: output)
        }
    }
}
