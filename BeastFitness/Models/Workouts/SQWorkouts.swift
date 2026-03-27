//
//  SQWorkouts.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 11/15/25.
//

import Foundation
import HealthKit
import SwiftUI

// MARK: - SQWorkouts
// Used to group workouts of the SAME type
final class SQWorkouts {
    let workouts: [SQWorkoutSessionable]
    
    var activityType: HKWorkoutActivityType? {
        workouts.first?.activityType
    }
    
    init(workouts: [SQWorkoutSessionable]) {
        self.workouts = workouts
    }
}

// MARK: - Formatting Helpers

extension SQWorkouts {

    func formattedTotalOutput(
            valueFont: Font = SQFont(type: .bodySmallBold).font,
            unitFont: Font = SQFont(type: .bodySmall).font,
            valueColor: Color = SQColor.textPrimary.color,
            unitColor: Color = SQColor.textSecondary.color
        ) -> AttributedString? {
            let (value, unit) = totalOutputStrings()
            return buildValueUnitString(
                value: value,
                unit: unit,
                valueFont: valueFont,
                unitFont: unitFont,
                valueColor: valueColor,
                unitColor: unitColor
            )
        }

        func formattedTime(
            valueFont: Font = SQFont(type: .bodySmallBold).font,
            unitFont: Font = SQFont(type: .bodySmall).font,
            valueColor: Color = SQColor.textPrimary.color,
            unitColor: Color = SQColor.textSecondary.color
        ) -> AttributedString? {
            let totalTime: TimeInterval = workouts.reduce(0) { partial, workout in
                partial + (workout.activeDuration ?? 0)
            }
            
            // No time at all → no stat
            guard totalTime > 0 else { return nil }
            
            return buildDurationAttributedString(
                seconds: totalTime,
                valueFont: valueFont,
                unitFont: unitFont,
                valueColor: valueColor,
                unitColor: unitColor
            )
        }

        func formattedCalories(
            valueFont: Font = SQFont(type: .bodySmallBold).font,
            unitFont: Font = SQFont(type: .bodySmall).font,
            valueColor: Color = SQColor.textPrimary.color,
            unitColor: Color = SQColor.textSecondary.color
        ) -> AttributedString? {
            let (value, unit) = totalCaloriesStrings()
            return buildValueUnitString(
                value: value,
                unit: unit,
                valueFont: valueFont,
                unitFont: unitFont,
                valueColor: valueColor,
                unitColor: unitColor
            )
        }

    func formattedHeartRate(
        valueFont: Font = SQFont(type: .bodySmallBold).font,
        unitFont: Font = SQFont(type: .bodySmall).font,
        valueColor: Color = SQColor.textPrimary.color,
        unitColor: Color = SQColor.textSecondary.color
    ) -> AttributedString? {
        // We don't actually need the unit from averageHeartRateStrings anymore
        let (value, _) = averageHeartRateStrings()
        guard let value, !value.isEmpty else { return nil }

        // Use a heart symbol instead of "count/min" or "bpm"
        let heartUnit = "♥︎"   // or "❤️" if you prefer the emoji

        return buildValueUnitString(
            value: value,
            unit: heartUnit,
            valueFont: valueFont,
            unitFont: unitFont,
            valueColor: valueColor,
            unitColor: unitColor
        )
    }
}

// MARK: - Formatting (Core)

private extension SQWorkouts {

    // MARK: Core builder

    func buildValueUnitString(
        value: String?,
        unit: String?,
        valueFont: Font,
        unitFont: Font,
        valueColor: Color,
        unitColor: Color
    ) -> AttributedString? {
        var result = AttributedString()

        if let value, !value.isEmpty {
            result.append(
                AttributedString.build(with: value, font: valueFont, color: valueColor)
            )
        }

        if let unit, !unit.isEmpty {
            result.append(
                AttributedString.build(with: " \(unit)", font: unitFont, color: unitColor)
            )
        }

        // If nothing was appended, treat as "no stat"
        return result.characters.isEmpty ? nil : result
    }

    // MARK: - Totals / Aggregates

    func totalOutputStrings() -> (String?, String?) {
        guard
            let first = workouts.first
        else {
            return (nil, nil)
        }

        var totalOutput = 0.0
        workouts.forEach { workout in
            totalOutput += workout.coreMetric?.value ?? 0
        }

        // If there's no meaningful output, return nil so nothing gets rendered
        guard totalOutput > 0 else {
            return (nil, nil)
        }

        let value = totalOutput.sqShortString
        let unit = first.coreMetric?.unit.unitString
        return (value, unit)
    }

    func totalTimeStrings() -> (String?, String?) {
        let totalTime: TimeInterval = workouts.reduce(0) { partial, workout in
            partial + (workout.activeDuration ?? 0)
        }

        let durationString = SQDateFormatters.shared.durationFormatter.string(from: totalTime)
        let (value, unit) = splitFormatted(durationString)
        return (value, unit)
    }

    func totalCaloriesStrings() -> (String?, String?) {
        var totalCalories = 0.0
        workouts.forEach { workout in
            totalCalories += workout.totalCalories ?? 0
        }

        // No calories → no stat
        guard totalCalories > 0 else {
            return (nil, nil)
        }

        let value = totalCalories.sqShortString
        let unit = SQQuantityType.activeKilocaloriesBurned.unit?.unitString
        return (value, unit)
    }
    
    func buildDurationAttributedString(
        seconds: TimeInterval,
        valueFont: Font,
        unitFont: Font,
        valueColor: Color,
        unitColor: Color
    ) -> AttributedString? {
        let total = max(0, Int(seconds.rounded()))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        
        var result = AttributedString()
        
        func appendPart(value: Int, symbol: String) {
            guard value > 0 else { return }
            
            if !result.characters.isEmpty {
                result.append(
                    AttributedString.build(with: " ", font: unitFont, color: unitColor)
                )
            }
            
            result.append(
                AttributedString.build(with: "\(value)", font: valueFont, color: valueColor)
            )
            result.append(
                AttributedString.build(with: symbol, font: unitFont, color: unitColor)
            )
        }
        
        appendPart(value: hours, symbol: "h")
        appendPart(value: minutes, symbol: "m")
        appendPart(value: secs, symbol: "s")
        
        // If everything was 0, treat as "no stat" here (caller already guards > 0)
        return result.characters.isEmpty ? nil : result
    }

    func averageHeartRateStrings() -> (String?, String?) {
        var totalTime: TimeInterval = 0.0
        var totalAvgHeartRateTimesSeconds = 0.0

        workouts.forEach { workout in
            guard let avgHR = workout.plausibleAverageHeartRate else { return }
            let duration = workout.activeDuration ?? 0
            guard duration > 0 else { return }
            totalTime += duration
            totalAvgHeartRateTimesSeconds += avgHR * duration
        }

        // No time → no HR stat
        guard totalTime > 0 else {
            return (nil, nil)
        }

        let averageHeartRate = totalAvgHeartRateTimesSeconds / totalTime
        
        // If avgHR is effectively zero, treat as missing
        guard averageHeartRate > 0 else {
            return (nil, nil)
        }

        let value = averageHeartRate.sqShortString
        let unit = SQQuantityType.heartRate.unit?.unitString
        return (value, unit)
    }

    // MARK: - String splitting

    func splitFormatted(_ string: String?) -> (String?, String?) {
        guard let s = string else { return (nil, nil) }
        let parts = s.split(separator: " ")

        if parts.count >= 2 {
            let value = String(parts[0])
            let unit = parts.dropFirst().joined(separator: " ")
            return (value, unit)
        }

        // If no space (e.g. "1:23:45"), treat all as value (all bold)
        return (s, nil)
    }
}
