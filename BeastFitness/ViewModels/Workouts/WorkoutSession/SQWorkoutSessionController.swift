//
//  SQWorkoutSessionViewModel.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 12/5/25.
//

import SwiftUI
import SwiftData
import HealthKit
import BeastFitnessCore

@Observable
@MainActor
final class SQWorkoutSessionController: Identifiable {
    let id = UUID()
    private let workoutManager: SQWorkoutManaging
    let state: WorkoutSessionStating
    let interface: SQWorkoutsLandingInterface = SQWorkoutsLandingController.default
    var onDismiss: () -> Void
    
    // MARK: - Timer
    let timerViewModel = SQWorkoutSessionTimerViewModel()
    let restTimerViewModel = SQWorkoutSessionRestTimerViewModel()
    var navBarTimeString: String {
        if restTimerViewModel.isPresentedAsActive {
            return "Rest · \(restTimerViewModel.remainingString)"
        } else {
            return "Workout · \(timerViewModel.visibleTimeString)"
        }
    }
    
    @MainActor
    static func `default`(for workout: SQWorkoutSessionable?, onDismiss: @escaping () -> Void) -> SQWorkoutSessionController {
        Self.default.onDismiss = onDismiss
        Self.default.reset(with: workout)
        print("PTD Default Session Controller")
        self.default.startWorkout(displayWatchPrompt: true)
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
        timerViewModel.stop()
        state.load(workout: workout)
    }
    
    private func startWorkout(displayWatchPrompt: Bool = false) {
        print("PTD Starting workout", displayWatchPrompt)
        if displayWatchPrompt {
            state.hub.alertEvents.send(.present(.init(
                title: "Start workout on Apple Watch to track metrics?",
                primary: .init(
                    title: "Start on Apple Watch",
                    handler: { [weak self] in
                        guard let self else { return }
                        SQWatchInterface.shared.startStrengthWorkoutOnWatch()
                        self.startWorkout()
                    }),
                secondary: .init(
                    title: "Start without Apple Watch",
                    handler: { [weak self] in
                        guard let self else { return }
                        self.startWorkout()
                    })
            )))
            return
        }
        
        timerViewModel.start()
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
    
    func buildSession() -> SQWorkoutSessionable {
        let details = SQWorkoutActivityDetails.strength(buildStrengthDetails())
        
        let baseWorkout = state.baseWorkout
        let title = state.titleTextField?.text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // TODO: - PTD Finish building out manual workout source here with full data (elapsed time, heart rate, etc...)
        let workoutId = baseWorkout?.id ?? UUID().uuidString
        
        /// ✅ Snapshot time once so all fields are consistent
        let now = Date()
        let startDate = timerViewModel.workoutStartDate
        let activeDuration = timerViewModel.hasStarted ? timerViewModel.currentActiveDuration(at: now) : nil
        let endDate: Date? = now
        
        let workoutSource = baseWorkout?.workoutSource
        ?? .manual(SQManualWorkout(
            sourceId: workoutId,
            activityType: .traditionalStrengthTraining,
            device: nil,
            startDate: startDate,
            endDate: endDate,
            activeDuration: activeDuration,
            averageHeartRate: nil,
            totalCalories: nil,
            details: details))
        
        return SQWorkoutSession(
            workoutSource: workoutSource,
            overrideData: SQConcreteWorkoutSessionOverridableData(title: title, details: details),
            hkWorkoutId: nil)
    }
    
    func saveWorkout(to modelContext: ModelContext) async {
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
