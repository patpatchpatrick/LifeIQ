//
//  SQWatchWorkoutPayload+Extensions.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 12/30/25.
//

import BeastFitnessCore

extension SQWatchWorkoutPayload {

    @MainActor
    static func build(
        activeExercise: SQWorkoutSessionExerciseViewModel?,
        activeSetIndex: Int?
    ) -> SQWatchWorkoutPayload {

        guard let exercise = activeExercise else {
            return SQWatchWorkoutPayload(activeExercise: nil)
        }

        let activeSet: ActiveSet? = {
            guard
                let idx = activeSetIndex,
                idx >= 0,
                idx < exercise.sets.count
            else { return nil }

            let set = exercise.sets[idx]
            return ActiveSet(
                setNumber: set.setIndex,
                reps: set.reps,
                weight: set.weight,
                isCompleted: set.isCompleted
            )
        }()

        let activeExercisePayload = ActiveExercise(
            rawExerciseId: exercise.rawExerciseId,
            name: exercise.name,
            activeSet: activeSet
        )

        return SQWatchWorkoutPayload(activeExercise: activeExercisePayload)
    }
}
