//
//  SQWorkoutSessionViewModel.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 12/5/25.
//

import SwiftUI
import SwiftData
import HealthKit

@Observable
@MainActor
final class SQWorkoutSessionController: Identifiable {
    let id = UUID()
    private let workoutManager: SQWorkoutManaging
    let state: WorkoutSessionStating
    let interface: SQWorkoutsLandingInterface = SQWorkoutsLandingController.default
    var onDismiss: () -> Void
    
    // MARK: - Timer

    // MARK: - Timer

    private var timer: Timer?

    var isTimerRunning: Bool = false

    private var workoutStartDate: Date?
    private var runningStartDate: Date?          // when the current "segment" began
    private var accumulatedElapsed: TimeInterval = 0  // total elapsed excluding current segment

    var elapsedTime: TimeInterval = 0            // derived / published for UI
    var hasTimerStarted: Bool {
        accumulatedElapsed > 0 || runningStartDate != nil
    }
    

    // MARK: - Timer controls

    func startTimerIfNeeded() {
        guard runningStartDate == nil, accumulatedElapsed == 0 else { return }

        workoutStartDate = Date()
        accumulatedElapsed = 0
        elapsedTime = 0
        resumeTimer()
    }

    func resumeTimer() {
        guard !isTimerRunning else { return }

        // Start a new running segment from "now"
        runningStartDate = Date()
        isTimerRunning = true

        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                guard self.isTimerRunning else { return }
                let now = Date()
                let segment = now.timeIntervalSince(self.runningStartDate ?? now)
                self.elapsedTime = self.accumulatedElapsed + segment
            }
        }
    }

    func pauseTimer() {
        guard isTimerRunning else { return }

        let now = Date()
        if let start = runningStartDate {
            accumulatedElapsed += now.timeIntervalSince(start)
        }

        // Freeze
        elapsedTime = accumulatedElapsed
        runningStartDate = nil
        isTimerRunning = false

        timer?.invalidate()
        timer = nil
    }

    func stopTimer() {
        workoutStartDate = nil
        runningStartDate = nil
        accumulatedElapsed = 0
        elapsedTime = 0
        isTimerRunning = false

        timer?.invalidate()
        timer = nil
    }
    
    private func currentActiveDuration(at now: Date = Date()) -> TimeInterval {
        if isTimerRunning, let start = runningStartDate {
            return accumulatedElapsed + now.timeIntervalSince(start)
        } else {
            return accumulatedElapsed
        }
    }
    
    var elapsedTimeString: String {
        let total = max(0, Int(elapsedTime))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, s)
            : String(format: "%d:%02d", m, s)
    }
    
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
        state.load(workout: workout)
        startTimerIfNeeded()
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
        let startDate = workoutStartDate
        let activeDuration = hasTimerStarted ? currentActiveDuration(at: now) : nil
        let endDate: Date? = now
        
        let workoutSource = baseWorkout?.workoutSource
        ?? .manual(SQManualWorkout(
            sourceId: workoutId,
            activityType: .functionalStrengthTraining,
            device: nil,
            startDate: startDate,
            endDate: endDate,
            activeDuration: activeDuration,
            averageHeartRate: nil,
            totalCalories: nil,
            details: details))
        
        return workoutSource.buildWorkout(withOverrideData: SQConcreteWorkoutSessionOverridableData(title: title, details: details))
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
