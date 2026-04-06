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
    let warningText: String?

    var displayUnit: SQUnit {
        quantityType.preferredDisplayUnit ?? unit
    }

    var displayValue: Double {
        displayValue(forRawValue: value)
    }
    
    var outputAndUnitString: String {
        "\(displayableValue(for: quantityType, value: displayValue)) \(displayUnit.unitString ?? "")"
    }

    func displayValue(forRawValue rawValue: Double) -> Double {
        unit.convert(rawValue, to: displayUnit) ?? rawValue
    }
    
    func displayableValue(for quantityType: SQQuantityType, value: Double) -> String {
        switch quantityType {

        case .distanceWalkingRunning, .distanceCycling, .distanceSwimming, .distanceRowing, .distanceDownhillSnowSports, .distanceCrossCountrySkiing, .flightsClimbed, .activeKilocaloriesBurned, .heartRate, .sqTotalVolumeLifted, .unknown:
            return value.sqShortString

        case .sqPaceRunning, .sqFastestPace:
            return value.timeCode() /// eg 7:43
        }
    }

    static func mock(for quantityType: SQQuantityType) -> SQWorkoutMetric {
        let unit = quantityType.unit ?? .unknown
        let mockValue: Double

        switch quantityType {
        case .distanceWalkingRunning:
            mockValue = 5.2
        case .sqPaceRunning, .sqFastestPace:
            mockValue = 450.0 // 7:30 pace in seconds
        case .activeKilocaloriesBurned:
            mockValue = 425.0
        case .heartRate:
            mockValue = 152.0
        default:
            mockValue = 100.0
        }

        return SQWorkoutMetric(
            quantityType: quantityType,
            displayName: quantityType.displayTitle,
            unit: unit,
            value: mockValue,
            warningText: nil
        )
    }
}

// MARK: - SQWorkoutSession Build Metrics

extension SQWorkoutSession {

    static func getMetric(for quantityType: SQQuantityType, workoutSource: SQWorkoutSource) async -> SQWorkoutMetric? {
        guard let unit = quantityType.unit
        else {
            return nil
        }

        switch quantityType.outputCalculationType {

        case .fastestPace(let distance):
            guard let result = await workoutSource.sourcableData.fastestPaceFor(distance) else { return nil }

            return .init(
                quantityType: quantityType,
                displayName: quantityType.displayTitle,
                unit: unit,
                value: result.pace,
                warningText: result.calculationMethod.warningText
            )

        case .sum:

            guard let output = workoutSource.sourcableData.sumOutputFor(quantityType) else { return nil }

            return .init(
                quantityType: quantityType,
                displayName: quantityType.displayTitle,
                unit: unit,
                value: output,
                warningText: nil)

        case .average:

            guard let output = workoutSource.sourcableData.avgOutputFor(quantityType) else { return nil }
            if quantityType == .heartRate, (output < 30 || output > 240) {
                return nil
            }

            return .init(
                quantityType: quantityType,
                displayName: quantityType.displayTitle,
                unit: unit,
                value: output,
                warningText: nil)
        }
    }
}
