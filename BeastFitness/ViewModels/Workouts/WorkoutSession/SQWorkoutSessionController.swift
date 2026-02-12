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
import Combine

@Observable
@MainActor
final class SQWorkoutSessionController: Identifiable {
    let id = UUID()
    private var cancellables = Set<AnyCancellable>()
    static let defaultStrengthActivity: HKWorkoutActivityType = .traditionalStrengthTraining
    private let exercisesManager: SQExercisesManaging
    private let workoutManager: SQWorkoutManaging
    let state: WorkoutSessionStating
    let interface: SQWorkoutsLandingInterface = SQWorkoutsLandingController.default
    let watchInterface: SQWatchInterfacing = SQWatchInterface.shared
    var onDismiss: () -> Void
    private(set) var shouldDisplayTimer: Bool = true
    private(set) var workoutTitle: String = "Workout"
    private(set) var displayDiscardButton: Bool = false
    private(set) var workoutMode: WorkoutMode = .new
    private var hasStartedWorkout: Bool = false
    
    // MARK: - Timer
    let timerViewModel = SQWorkoutSessionTimerViewModel()
    let restTimerViewModel = SQWorkoutSessionRestTimerViewModel()
    var navBarTimeString: String {
        if workoutMode.shouldDisplayTimer {
            if restTimerViewModel.isPresentedAsActive {
                return "Rest · \(restTimerViewModel.remainingString)"
            } else {
                return "Workout · \(timerViewModel.visibleTimeString)"
            }
        } else {
            return "Workout"
        }
    }
    
    @MainActor
    static func `default`(for workout: SQWorkoutSessionable?, onDismiss: @escaping () -> Void) -> SQWorkoutSessionController {
        print("PTD Reset from default")
        Self.default.onDismiss = onDismiss
        return Self.default
    }
    
    @MainActor
    static let `default` = SQWorkoutSessionController(state: SQAppState.shared.workoutSessionState, onDismiss: {})
    
    init(state: WorkoutSessionStating, session: SQWorkoutSessionable? = nil, workoutManager: SQWorkoutManaging = SQWorkoutManager(), onDismiss: @escaping () -> Void) {
        self.state = state
        self.workoutManager = workoutManager
        self.exercisesManager = SQExercisesManager.shared
        self.onDismiss = onDismiss
        print("PTD Reset from init")
        reset(with: session)
        handleEventSubscriptions(hub: state.hub)
    }
    
    /// Should be called everytime before the view will appear
    func willAppear(with workout: SQWorkoutSessionable?) {
        reset(with: workout)
    }
    
    private func reset(with workout: SQWorkoutSessionable?) {
        SQLogger.shared.log("Resetting workout: \(workout?.id ?? "nil")", .debug, context: .workoutSession)
        hasStartedWorkout = false
        timerViewModel.stop()
        Task {
            await state.load(workout: workout)
        }

        let workoutMode: WorkoutMode = workout == nil ? .new : .existing
        self.workoutMode = workoutMode
        shouldDisplayTimer = workoutMode.shouldDisplayTimer
        displayDiscardButton = workoutMode.shouldDisplayDiscardButton
    }
    
    func onAppear() {
        guard !hasStartedWorkout else { return }
        hasStartedWorkout = true
        if workoutMode.shouldStartWorkoutOnLaunch {
            startWorkout(displayWatchPrompt: true)
        }
    }
    
    // MARK: - Subscriptions
    
    private func handleEventSubscriptions(hub: EventHub) {
        hub.workoutEvents.sink { [weak self] event in
            guard let self else { return }
            switch event {
            case .workoutsUpdated, .workoutsDeleted:
                /// No-op
                break
                
            case .activeWorkoutUpdate(let payload):
                do {
                    try watchInterface.sendActiveWorkoutPayloadToWatch(payload)
                } catch {
                    // TODO: - PTD should we surface an error to user when active workout data fails to sync with the watch? Maybe after a few failures in a row, we show some type of warning
                }
            }
        }.store(in: &cancellables)
    }
    
    // MARK: - Start workout
    
    private func startWorkout(displayWatchPrompt: Bool = false) {
        
        SQLogger.shared.log("Starting workout. Display watch prompt: \(displayWatchPrompt)", .debug, context: .workoutSession)
        
        if displayWatchPrompt {
            state.hub.alertEvents.send(.present(.init(
                title: "Start workout on Apple Watch to track metrics?",
                primary: .init(
                    title: "Start on Apple Watch",
                    handler: { [weak self] _ in
                        guard let self else { return }
                        watchInterface.startStrengthWorkoutOnWatch()
                        self.startWorkout()
                    }),
                secondary: .init(
                    title: "Start without Apple Watch",
                    handler: { [weak self] _ in
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
        exercisesManager.markExerciseUsed(id: rawExercise.id)
        state.appendExercises([rawExercise])
    }
    
    func removeExercise(_ exercise: UUID) {
        state.removeExercises([exercise])
    }
    
    // MARK: - Workout Data Handling (CRUD)
    func workoutChanged() {
        
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
            activityType: Self.defaultStrengthActivity,
            device: nil,
            startDate: startDate,
            endDate: endDate,
            activeDuration: activeDuration,
            averageHeartRate: nil,
            totalCalories: nil,
            details: details))
        
        return SQWorkoutSession(
            id: workoutId,
            workoutSource: workoutSource,
            overrideData: SQConcreteWorkoutSessionOverridableData(title: title, details: details),
            hkWorkoutId: nil)
    }
    
    func saveWorkout(to modelContext: ModelContext) async {
        
        func finishWorkout() async {
            let workout = buildSession()
            do {
                try await workoutManager.saveWorkout(workout: workout, to: modelContext)
                state.workoutUpdated(workout: workout)
                onDismiss()
            } catch {
                state.hub.alertEvents.send(.present(.init(SQError.standard(withDescription: "Error saving workout: \(error.localizedDescription)."))))
                SQLogger.shared.log("Error saving workout: \(error)", .debug, context: .workoutSession)
            }
        }
        
        let hasIncompleteExercises = state.exercises.contains(where: { $0.isCompleted == false })
        if hasIncompleteExercises {
            state.hub.alertEvents.send(.present(.init(
                title: "Save Workout",
                subtitle: "There are some incomplete exercises. How would you like to handle them?",
                primary: .init(
                    title: "Save",
                    role: .normal,
                    handler: { context in
                        Task { [weak self] in
                            guard let self else { return }
                            
                            if context?.selectedDropDownId == WorkoutSaveOptions.markAllExerciseCompleted.id {
                                print("PTD Marking all exercises completed ")
                                self.state.exercises.forEach { $0.sets.forEach { $0.isCompleted = true } }
                            }
                            
                            await finishWorkout()
                        }
                    }),
                secondary: .init(
                    title: "Cancel",
                    role: .cancel),
                dropDown: .init(
                    options: WorkoutSaveOptions.allCases.map { .init(id: $0.id, title: $0.title) },
                    defaultSelectedOptionId: WorkoutSaveOptions.markAllExerciseCompleted.id))
            ))
        } else {
            await finishWorkout()
        }
    }
    
    func discardWorkout() {
        state.hub.alertEvents.send(.present(.init(
            title: "Dismiss workout?",
            subtitle: "Workout data will be discarded",
            primary: .init(
                title: "Dismiss",
                role: .destructive,
                handler: { [weak self] _ in
                    guard let self else { return }
                    self.onDismiss()
                }),
            secondary: .init(
                title: "Cancel",
                role: .cancel)
        )))
    }
    
    // MARK: - Workout Mode
    
    enum WorkoutMode {
        case new
        case existing
        
        var shouldDisplayTimer: Bool {
            switch self {
            case .new:
                return true
            case .existing:
                return false
            }
        }
        
        var shouldStartWorkoutOnLaunch: Bool {
            switch self {
            case .new:
                return true
            case .existing:
                return false
            }
        }
        
        var shouldDisplayDiscardButton: Bool {
            switch self {
            case .new:
                return true
            case .existing:
                return false
            }
        }
    }
    
    // MARK: - Workout Save Options
    
    enum WorkoutSaveOptions: CaseIterable {
        case markAllExerciseCompleted
        case leaveExercisesAsIs
        
        var id: String {
            switch self {
            case .markAllExerciseCompleted:
                "all-complete"
            case .leaveExercisesAsIs:
                "leave"
            }
        }
        
        var title: String {
            switch self {
            case .markAllExerciseCompleted:
                "Mark all exercises as completed"
            case .leaveExercisesAsIs:
                "Leave exercises incomplete"
            }
        }
    }
}
