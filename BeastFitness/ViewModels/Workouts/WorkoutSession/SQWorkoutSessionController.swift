//
//  SQWorkoutSessionViewModel.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 12/5/25.
//

import SwiftUI
import SwiftData

@Observable
@MainActor
final class SQWorkoutSessionController: Identifiable {
    let id = UUID()
    private let workoutManager: SQWorkoutManaging
    let state: WorkoutSessionStating
    let interface: SQWorkoutsLandingInterface = SQWorkoutsLandingController.default
    var onDismiss: () -> Void
    
    @MainActor
    static func `default`(for workout: SQWorkoutSessionable?, onDismiss: @escaping () -> Void) -> SQWorkoutSessionController {
        Self.default.onDismiss = onDismiss
        Self.default.reset(with: workout)
        return Self.default
    }
    
    @MainActor
    static let `default` = SQWorkoutSessionController(state: AppState.shared.workoutSessionState, onDismiss: {})
    
    init(state: WorkoutSessionStating, session: SQWorkoutSessionable? = nil, workoutManager: SQWorkoutManaging = SQWorkoutManager(), onDismiss: @escaping () -> Void) {
        self.state = state
        self.workoutManager = workoutManager
        self.onDismiss = onDismiss
        reset(with: session)
    }
    
    private func reset(with workout: SQWorkoutSessionable?) {
        print("PTD Resetting workout session with workout", workout)
        state.load(workout: workout)
    }
    
    // MARK: - Derived
    
    var totalVolume: Double {
        state.exercises.reduce(0) { $0 + $1.totalVolume }
    }
    
    var isEmpty: Bool {
        state.exercises.isEmpty
    }
    
    var allCompleted: Bool {
        !state.exercises.isEmpty && state.exercises.allSatisfy { $0.isCompleted }
    }
    
    // MARK: - Exercise management
    
    func addExercise(
        rawExercise: SQRawStrengthExercise
    ) {
        let vm = SQWorkoutSessionExerciseViewModel(
            name: rawExercise.name,
            muscleGroup: rawExercise.primaryMuscles.first ?? .unknown,
            onRemoveExercise: { [weak self] exerciseId in
                self?.removeExercise(exerciseId)
            }
        )
        state.appendExercises([vm])
    }
    
    func removeExercise(_ exercise: UUID) {
        state.removeExercises([exercise])
    }
    
    // MARK: - Build domain models
    
    func buildStrengthDetails() -> SQStrengthDetails {
        let models = state.exercises.map { $0.asModel() }
        let groups = Array(Set(models.map { $0.muscleGroup }))
        
        return SQStrengthDetails(
            muscleGroups: groups,
            exercises: models
        )
    }
    
    func buildSession() -> SQWorkoutSession {
        let details = SQWorkoutDetails.strength(buildStrengthDetails())
        
        let baseWorkout = state.baseWorkout
        let title = state.titleTextField?.text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // TODO: - PTD Finish building out manual workout source here with full data (elapsed time, heart rate, etc...)
        let workoutId = baseWorkout?.id ?? UUID().uuidString
        
        return SQWorkoutSession(
            title: title,
            workoutSource: .manual(.init(
                sourceId: workoutId,
                activityType: .functionalStrengthTraining,
                device: nil,
                startDate: baseWorkout?.startDate,
                endDate: baseWorkout?.endDate,
                activeDuration: baseWorkout?.activeDuration,
                averageHeartRate: baseWorkout?.averageHeartRate,
                totalCalories: baseWorkout?.totalCalories,
                details: details)),
            device: baseWorkout?.device,
            activityType: baseWorkout?.activityType ?? .functionalStrengthTraining,
            activeDuration: baseWorkout?.activeDuration,
            startDate: baseWorkout?.startDate,
            endDate: baseWorkout?.endDate,
            totalCalories: baseWorkout?.totalCalories,
            averageHeartRate: baseWorkout?.averageHeartRate
        )
    }
    
    func saveWorkout(to modelContext: ModelContext) async {
        print("PTD workout controller save workout")
        let workout = buildSession()
        do {
            try await workoutManager.saveWorkout(workout: workout, to: modelContext)
            state.workoutUpdated(workout: workout)
            onDismiss()
        } catch {
            // TODO: - PTD Display modal error when saving workout
            SQLogger.shared.log("Error saving workout: \(error)", .debug, context: .workoutSession)
        }
    }
}


@Observable
@MainActor
final class SQWorkoutSessionExerciseViewModel: Identifiable {
    let id: UUID
    
    var name: String
    var muscleGroup: SQMuscleGroup
    let onRemoveExercise: ((UUID) -> Void)?
    private(set) var sets: [SQWorkoutSessionSetViewModel]
    
    init(
        id: UUID = UUID(),
        name: String,
        muscleGroup: SQMuscleGroup,
        sets: [SQWorkoutSessionSetViewModel],
        onRemoveExercise: ((UUID) -> Void)?
    ) {
        self.id = id
        self.name = name
        self.muscleGroup = muscleGroup
        self.sets = sets
        self.onRemoveExercise = onRemoveExercise
        renumberSets()
    }
    
    /// New exercise with 3 default sets
    convenience init(
        name: String,
        muscleGroup: SQMuscleGroup,
        defaultSetCount: Int = 3,
        defaultReps: Int = 8,
        defaultWeight: Double = 50,
        onRemoveExercise: ((UUID) -> Void)?
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
            sets: setVMs,
            onRemoveExercise: onRemoveExercise
        )
    }
    
    convenience init(from model: SQStrengthExercise, onRemoveExercise: ((UUID) -> Void)?) {
        let setVMs = model.sets
            .sorted { $0.setIndex < $1.setIndex }
            .map { SQWorkoutSessionSetViewModel(from: $0) }
        
        self.init(
            id: model.id,
            name: model.name,
            muscleGroup: model.muscleGroup,
            sets: setVMs,
            onRemoveExercise: onRemoveExercise
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
    
    func deleteExercise() {
        onRemoveExercise?(self.id)
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
