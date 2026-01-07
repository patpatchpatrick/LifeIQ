//
//  SQWorkoutSession+PrettyDescription.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 1/6/26.
//

import Foundation

// MARK: - Pretty Description

extension SQWorkoutSessionable {

    var prettyDescription: String {
        
        return "[SESSION] \(self.title) \(self.id) \(self.hkWorkoutId)"
        
        var lines: [String] = []

        // Header
        lines.append("🏃‍♂️ Workout Session")
        lines.append("")

        // Title / Activity
        lines.append("Title: \(visibleTitle)")
        lines.append("Activity: \(activityType.name)")
        lines.append("Source: \(workoutSource.prettyName)")

        if let device {
            lines.append("Device: \(device.prettyName)")
        }

        lines.append("")

        // Time
        if let startDate {
            lines.append("Start: \(startDate.prettyDateTime)")
        }

        if let endDate {
            lines.append("End: \(endDate.prettyDateTime)")
        }

        if let duration = activeDuration {
            lines.append("Duration: \(duration.prettyDuration)")
        }

        lines.append("")

        // Summary metrics
        if let totalCalories {
            lines.append("Calories: \(Int(totalCalories)) kcal")
        }

        if let averageHeartRate {
            lines.append("Avg HR: \(Int(averageHeartRate)) bpm")
        }
        
        // Details
        if let details {
            lines.append("")
            lines.append("Details:")
            lines.append(details.prettyDescription.indented(by: 2))
        }

        return lines.joined(separator: "\n")
    }
}

private extension SQWorkoutActivityDetails {

    var prettyDescription: String {
        switch self {
        case .strength(let strengthDetails):
            return strengthDetails.printableDescription
        default:
            return "No detailed breakdown available."
        }
    }
}

private extension Date {
    var prettyDateTime: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: self)
    }
}

private extension Double {
    var prettyDuration: String {
        let totalSeconds = Int(self)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        } else {
            return "\(seconds)s"
        }
    }
}

private extension String {
    func indented(by spaces: Int) -> String {
        let prefix = String(repeating: " ", count: spaces)
        return self
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { prefix + $0 }
            .joined(separator: "\n")
    }
}

private extension SQWorkoutSource {
    var prettyName: String {
        String(describing: self).capitalized
    }
}

private extension SQWorkoutDevice {
    var prettyName: String {
        String(describing: self).capitalized
    }
}
