//
//  SQWorkoutSessionViewModel.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 12/5/25.
//

import SwiftUI

@Observable
@MainActor
final class SQWorkoutSessionViewModel: Identifiable {
    let id = UUID()
    
    let interface: SQWorkoutsLandingInterface = SQWorkoutsLandingController.default
    
    private(set) var exercises: [SQWorkoutSessionExerciseViewModel] = []
    
    // Optional base session if you're editing
    private let baseSession: SQWorkoutSession?
    
    init(session: SQWorkoutSession? = nil) {
        self.baseSession = session
        
        if
            let session,
            case let .strength(details) = session.details
        {
            self.exercises = details.exercises.map { SQWorkoutSessionExerciseViewModel(from: $0) }
        } else {
            self.exercises = []
        }
    }
    
    // MARK: - Derived
    
    var totalVolume: Double {
        exercises.reduce(0) { $0 + $1.totalVolume }
    }
    
    var isEmpty: Bool {
        exercises.isEmpty
    }
    
    var allCompleted: Bool {
        !exercises.isEmpty && exercises.allSatisfy { $0.isCompleted }
    }
    
    // MARK: - Exercise management
    
    func addExercise(
        name: String = "New Exercise",
        muscleGroup: SQMuscleGroup = .unknown
    ) {
        let vm = SQWorkoutSessionExerciseViewModel(
            name: name,
            muscleGroup: muscleGroup
        )
        exercises.append(vm)
    }
    
    func removeExercise(_ exercise: SQWorkoutSessionExerciseViewModel) {
        exercises.removeAll { $0.id == exercise.id }
    }
    
    func moveExercise(fromOffsets: IndexSet, toOffset: Int) {
        exercises.move(fromOffsets: fromOffsets, toOffset: toOffset)
    }
    
    // MARK: - Build domain models
    
    func buildStrengthDetails() -> SQStrengthDetails {
        let models = exercises.map { $0.asModel() }
        let groups = Array(Set(models.map { $0.muscleGroup }))
        
        return SQStrengthDetails(
            muscleGroups: groups,
            exercises: models
        )
    }
    
    func buildSession() -> SQWorkoutSession {
        let details = SQWorkoutDetails.strength(buildStrengthDetails())
        
        if var baseSession {
            baseSession.details = details
            return baseSession
        } else {
            return SQWorkoutSession(
                id: UUID(),
                // TODO: - PTD Finish building out manual workout source here with full data (elapsed time, heart rate, etc...)
                workoutSource: .manual(.init(
                    id: UUID(),
                    activityType: .functionalStrengthTraining)),
                activityType: .functionalStrengthTraining,
                coreOutputQuantityTypeId: nil,
                coreOutputUnit: nil,
                activeDuration: nil,
                startDate: Date(),
                endDate: nil,
                totalCalories: nil,
                details: details
            )
        }
    }
}


@Observable
@MainActor
final class SQWorkoutSessionExerciseViewModel: Identifiable {
    let id: UUID
    
    var name: String
    var muscleGroup: SQMuscleGroup
    private(set) var sets: [SQWorkoutSessionSetViewModel]
    
    init(
        id: UUID = UUID(),
        name: String,
        muscleGroup: SQMuscleGroup,
        sets: [SQWorkoutSessionSetViewModel]
    ) {
        self.id = id
        self.name = name
        self.muscleGroup = muscleGroup
        self.sets = sets
        renumberSets()
    }
    
    /// New exercise with 3 default sets
    convenience init(
        name: String,
        muscleGroup: SQMuscleGroup,
        defaultSetCount: Int = 3,
        defaultReps: Int = 8,
        defaultWeight: Double = 50
    ) {
        let setVMs = (1...defaultSetCount).map { index in
            SQWorkoutSessionSetViewModel(
                setIndex: index,
                initialReps: defaultReps,
                initialWeight: defaultWeight
            )
        }
        
        self.init(
            name: name,
            muscleGroup: muscleGroup,
            sets: setVMs
        )
    }
    
    convenience init(from model: SQStrengthExercise) {
        let setVMs = model.sets
            .sorted { $0.setIndex < $1.setIndex }
            .map { SQWorkoutSessionSetViewModel(from: $0) }
        
        self.init(
            id: model.id,
            name: model.name,
            muscleGroup: model.muscleGroup,
            sets: setVMs
        )
    }
    
    // MARK: - Derived
    
    var isCompleted: Bool {
        !sets.isEmpty && sets.allSatisfy { $0.isCompleted }
    }
    
    var totalVolume: Double {
        sets.reduce(0) { $0 + $1.volume }
    }
    
    // MARK: - Mutations
    
    func addSet(copyLast: Bool = true) {
        let nextIndex = sets.count + 1
        
        if copyLast, let last = sets.last {
            let newSet = SQWorkoutSessionSetViewModel(
                setIndex: nextIndex,
                initialReps: last.reps,
                initialWeight: last.weight
            )
            sets.append(newSet)
        } else {
            let newSet = SQWorkoutSessionSetViewModel(
                setIndex: nextIndex,
                initialReps: 8,
                initialWeight: 50
            )
            sets.append(newSet)
        }
        
        renumberSets()
    }
    
    func removeSet(_ set: SQWorkoutSessionSetViewModel) {
        sets.removeAll { $0.id == set.id }
        renumberSets()
    }
    
    private func renumberSets() {
        for (idx, vm) in sets.enumerated() {
            vm.setIndex = idx + 1
        }
    }
    
    func asModel() -> SQStrengthExercise {
        SQStrengthExercise(
            id: id,
            name: name,
            muscleGroup: muscleGroup,
            sets: sets
                .sorted { $0.setIndex < $1.setIndex }
                .map { $0.asModel() }
        )
    }
}

@Observable
@MainActor
final class SQWorkoutSessionSetViewModel: Identifiable {
    let id: UUID
    var setIndex: Int
    
    let repsTextFieldViewModel: SQTextFieldViewModel
    let weightTextFieldViewModel: SQTextFieldViewModel
    
    var isCompleted: Bool = false
    
    init(
        id: UUID = UUID(),
        setIndex: Int,
        initialReps: Int = 8,
        initialWeight: Double = 50
    ) {
        self.id = id
        self.setIndex = setIndex
        
        // Reps: integer, 1...1000
        let repsVM = SQTextFieldViewModel(
            lineLimit: 1,
            placeholder: "Reps",
            keyboardType: .numberPad,
            textChangeFormatter: .integer,
            validationRule: .integer(range: 1...1000),
            errorHandler: { _ in nil }
        )
        repsVM.text = "\(initialReps)"
        self.repsTextFieldViewModel = repsVM
        
        // Weight: decimal, 0...2000
        let weightVM = SQTextFieldViewModel(
            lineLimit: 1,
            placeholder: "lbs",
            keyboardType: .decimalPad,
            textChangeFormatter: .decimal(maxDecimalPlaces: 1),
            validationRule: .decimal(maxDecimalPlaces: 1, range: 0...2000),
            errorHandler: { _ in nil }
        )
        weightVM.text = String(format: "%.1f", initialWeight)
        self.weightTextFieldViewModel = weightVM
    }
    
    convenience init(from model: SQStrengthSet) {
        self.init(
            id: model.id,
            setIndex: model.setIndex,
            initialReps: model.reps,
            initialWeight: model.weight
        )
        // rpe / isWarmup not surfaced in UI yet; easy to add later.
    }
    
    // Derived values from text
    var reps: Int {
        Int(repsTextFieldViewModel.text) ?? 0
    }
    
    var weight: Double {
        Double(weightTextFieldViewModel.text) ?? 0
    }
    
    var volume: Double {
        Double(reps) * weight
    }
    
    func asModel() -> SQStrengthSet {
        SQStrengthSet(
            id: id,
            setIndex: setIndex,
            reps: reps,
            weight: weight,
            rpe: nil,
            isWarmup: false
        )
    }
}
