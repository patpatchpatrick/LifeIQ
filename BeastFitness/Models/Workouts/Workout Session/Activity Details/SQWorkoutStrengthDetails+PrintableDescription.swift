//
//  SQWorkoutStrengthDetails+PrintableDescription.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 1/6/26.
//

private extension Double {
    var formattedWeight: String {
        if self.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(self))"
        } else {
            return String(format: "%.1f", self)
        }
    }
}


private extension SQMuscleGroup {
    var prettyName: String {
        rawValue
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
    }
}


private extension SQStrengthSet {

    var printableDescription: String {
        var parts: [String] = []

        parts.append("Set \(setIndex): \(reps) reps")

        if let weight {
            parts.append("× \(weight.formattedWeight)")
        }

        if let rpe {
            parts.append("(RPE \(String(format: "%.1f", rpe)))")
        }

        if isWarmup {
            parts.append("[Warm-up]")
        }

        if let isCompleted, !isCompleted {
            parts.append("[Not completed]")
        }

        return "• " + parts.joined(separator: " ")
    }
}


extension SQStrengthDetails {

    var printableDescription: String {
        
        var lines: [String] = []

        // Header
        lines.append("🏋️ Strength Workout")
        lines.append("")

        // Muscle groups
        if !muscleGroups.isEmpty {
            let muscleNames = muscleGroups
                .map { $0.prettyName }
                .sorted()
                .joined(separator: ", ")

            lines.append("Muscle Groups:")
            lines.append("• \(muscleNames)")
            lines.append("")
        }

        // Exercises
        for exercise in exercises {
            lines.append("🔹 \(exercise.name)  (\(exercise.muscleGroup.prettyName))")

            for set in exercise.sets.sorted(by: { $0.setIndex < $1.setIndex }) {
                lines.append("  \(set.printableDescription)")
            }

            lines.append("  ↳ Volume: \(exercise.totalVolume.formattedWeight)")
            lines.append("")
        }

        // Total volume
        lines.append("Total Volume: \(totalVolume.formattedWeight)")

        return lines.joined(separator: "\n")
    }
}
