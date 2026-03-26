//
//  SQWorkoutSummaryView.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 12/6/25.
//

import SwiftUI
import SwiftData
import Combine
import BeastFitnessCore
import CoreLocation
import HealthKit

enum SQWorkoutSummaryMode: Equatable {
    case standard
    case review
}

struct SQWorkoutReviewHighlight: Identifiable {
    let id = UUID()
    let segments: [Segment]
    let sentiment: Sentiment

    struct Segment {
        let text: String
        let isStatistic: Bool
    }

    enum Sentiment: Equatable {
        case positive, neutral, negative
    }
}

@MainActor
protocol SQWorkoutSummaryInterface {
    func pushEditWorkoutView()
}

@Observable @MainActor
final class SQWorkoutSummaryController: SQWorkoutSummaryInterface {
    var dismissKeyboard: Bool = false /// Toggle to dismiss keyboard
    let id = UUID().uuidString
    let state: WorkoutSummaryStating
    let mode: SQWorkoutSummaryMode

    // Review state — only populated when mode == .review
    var selectedPerformance: SQSegmentedControlSegment? = nil {
        didSet { persistReviewDataIfNeeded() }
    }
    var selectedDifficulty: SQSegmentedControlSegment? = nil {
        didSet { persistReviewDataIfNeeded() }
    }
    let titleViewModel: SQUITextFieldViewModel
    let notesViewModel: SQTextFieldViewModel = .init(
        axis: .vertical,
        lineLimit: 5,
        placeholder: "How'd it go? Any notes...",
        textAutoCap: .sentences,
        autoCorrectionEnabled: true
    )
    let temperatureViewModel: SQUITextFieldViewModel = SQUITextFieldViewModel(
        placeholder: "72",
        font: SQFont(type: .body).uiFont,
        keyboardType: .decimalPad,
        autocapitalizationType: .none,
        autocorrectionType: .no,
        textChangeFormatter: .decimal(maxDecimalPlaces: 1)
    )
    var reviewHighlights: [SQWorkoutReviewHighlight] = []

    let navigationTitle: String
    private var cancellables = Set<AnyCancellable>()
    private var isWorkoutLoaded = false

    static let performanceSegments: [SQSegmentedControlSegment] = [
        .init(id: "perf-1", title: "😞", ratingValue: 2),
        .init(id: "perf-2", title: "😐", ratingValue: 4),
        .init(id: "perf-3", title: "🙂", ratingValue: 6),
        .init(id: "perf-4", title: "😄", ratingValue: 8),
        .init(id: "perf-5", title: "🔥", ratingValue: 10),
    ]

    static let difficultySegments: [SQSegmentedControlSegment] = [
        .init(id: "diff-1", title: "😴", ratingValue: 2),
        .init(id: "diff-2", title: "🙂", ratingValue: 4),
        .init(id: "diff-3", title: "😤", ratingValue: 6),
        .init(id: "diff-4", title: "💪", ratingValue: 8),
        .init(id: "diff-5", title: "💀", ratingValue: 10),
    ]

    private let workoutManager: SQWorkoutManaging
    private let healthKitManager: SQHealthKitManaging
    private let statsManager: SQWorkoutStatsManaging
    private let workout: SQWorkoutSessionable
    
    var navTitle: String {
        switch mode {
        case .standard: return state.workoutTitle ?? workout.visibleTitle
        case .review: return "Nice workout! 💪"
        }
    }
    let showNavEditWorkoutButton: Bool

    init(workoutManager: SQWorkoutManaging = SQWorkoutManager.shared, healthKitManager: SQHealthKitManaging = SQHealthKitManager.shared, statsManager: SQWorkoutStatsManaging = SQWorkoutStatsManager.shared, workout: SQWorkoutSessionable, mode: SQWorkoutSummaryMode = .standard) {
        self.state = WorkoutSummaryState(hub: SQAppState.shared.hub)
        self.workoutManager = workoutManager
        self.healthKitManager = healthKitManager
        self.workout = workout
        self.statsManager = statsManager
        self.mode = mode
        self.navigationTitle = mode == .review ? "" : "Workout summary"
        self.titleViewModel = SQUITextFieldViewModel(
            placeholder: workout.visibleTitle,
            font: SQFont(type: .body).uiFont,
            autocapitalizationType: .sentences,
            autocorrectionType: .yes,
            textChangeFormatter: .maxLength(SQWorkoutSession.titleMaxChars)
        )
        
        switch mode {
        case .standard:
            showNavEditWorkoutButton = true
            state.shouldReactToWorkoutUpdates = true
        case .review:
            /// Don't push to edit workout screen from review mode, because user can already edit the workout from the review page itself. And it causes a SwiftData race condition if we push to this view (because both views are editing the same data)
            showNavEditWorkoutButton = false
            // Review mode is the source of saves, so suppress self-reload from its own events.
            state.shouldReactToWorkoutUpdates = false
        }
        
        setupEventSubscriptions()
    }
    
    func onAppear() async {
        await load(workout: workout)
    }

    private var hasLoaded = false
    private func load(workout: any SQWorkoutSessionable) async {
        guard !hasLoaded else { return }
        hasLoaded = true
        state.isLoading = true
        state.reset()
        await state.load(workout: workout)
        await loadRouteIfNeeded()
        await loadPerformanceDataIfNeeded(workout: workout)
        state.isLoading = false

        if mode == .review {
            titleViewModel.setText(workout.visibleTitle)
            notesViewModel.initializeText(workout.reviewNotes ?? "")
            // Temperature: prefer stored value, then try HealthKit metadata
            let farenheitRoundedDecimalPlaces = 0
            if let stored = workout.temperatureCelsius,
               let fahrenheit = SQUnit.degreesCelsius.convert(stored, to: .degreesFahrenheit) {
                temperatureViewModel.setText(fahrenheit.sqStringRoundedTo(places: farenheitRoundedDecimalPlaces))
            } else if case .hkWorkout(let hk) = workout.workoutSource,
                      let celsius = healthKitManager.weatherTemperatureCelsius(from: hk.hkWorkout),
                      let fahrenheit = SQUnit.degreesCelsius.convert(celsius, to: .degreesFahrenheit) {
                temperatureViewModel.setText(fahrenheit.sqStringRoundedTo(places: farenheitRoundedDecimalPlaces))
            }

            selectedPerformance = workout.ratingUserPerformance.flatMap { rating in
                Self.performanceSegments.first { $0.ratingValue == rating }
            }
            selectedDifficulty = workout.ratingDifficulty.flatMap { rating in
                Self.difficultySegments.first { $0.ratingValue == rating }
            }
            
            reviewHighlights = await statsManager.generateHighlights(
                for: workout,
                performanceData: state.performanceRowData
            )
        }
        isWorkoutLoaded = true
        if mode == .review {
            setupReviewSaveSubscriptions()
        }
    }

    func displayLeaderboard(for rowData: SQPerformanceRowData) {
        
        
        guard let mode = rowData.leaderboardMode else {
            SQLogger.shared.log(
                "Cannot display leaderboard: row '\(rowData.title)' does not have a leaderboard mode",
                .debug,
                context: .workoutSummary
            )
            return
        }

        SQLogger.shared.log(
            "Displaying leaderboard for '\(rowData.title)'",
            .debug,
            context: .workoutSummary
        )

        let leaderboardController = SQLeaderboardController(
            hub: state.hub,
            mode: mode,
            initialTimeRange: .allTime
        )
        
        /// Dismiss the keyboard, otherwise it automatically appears when we return to page and covers the action bar 
        dismissKeyboard.toggle()
        
        state.hub.domainEvents.send(.pushDashboardRoute(.leaderboard(controller: leaderboardController)))
    }

    func pushEditWorkoutView() {
        guard let baseWorkout = state.currentWorkout else {
            SQLogger.shared.log("Workout missing. Can't push edit workout screen.", .error, context: .workoutSummary)
            return
        }

        state.hub.domainEvents.send(.pushDashboardRoute(.editWorkout(workout: baseWorkout)))
    }

    func deleteWorkout(from modelContext: ModelContext) async {
        guard let baseWorkout = state.currentWorkout else {
            SQLogger.shared.log("Workout missing. Can't delete workout.", .error, context: .workoutSummary)
            return
        }

        let deletionType = workoutManager.deletionTypeForWorkout(baseWorkout)
        let title: String = "Delete workout?"
        let subtitle: String

        switch deletionType {
        case .hiddenHealtKit:
            subtitle = "This workout can't be deleted from HealthKit since it wasn't created by this app. But it will be hidden. Go to Settings to unhide workouts."
        case .hiddenStrava:
            subtitle = "This workout can't be deleted from Strava since it wasn't created by this app. But it will be hidden. Go to Settings to unhide workouts."
        case .standard:
            subtitle = "This workout will be deleted from both HealthKit and this app."
        }

        state.hub.alertEvents.send(.present(.init(
            title: title,
            subtitle: subtitle,
            primary: .init(title: "Delete workout?", handler: { _ in
                Task { [weak self] in
                    guard let self else { return }
                    do {
                        try await workoutManager.deleteWorkout(workout: baseWorkout, from: modelContext)
                        state.notifyAppOfWorkoutDeletion(workout: baseWorkout)
                        state.hub.domainEvents.send(.popDashboardRoute)
                    } catch {
                        state.hub.alertEvents.send(.present(.init(error as? SQUserFacingError ?? SQError.standard)))
                    }
                }
            }),
            secondary: .init(title: "Cancel", role: .cancel))))
    }
}

// MARK: - Review Persistence

extension SQWorkoutSummaryController {

    private func setupEventSubscriptions() {
        // WorkoutSummaryState has its own workoutEvents subscription that calls
        // state.load() on updates, refreshing all @Observable state properties the
        // view reads. navTitle is a computed var from state.workoutTitle so it also
        // auto-updates. We intentionally avoid pushing values into editable text field
        // VMs here — in review mode those have debounced save subscriptions that would
        // cause a save → workoutsUpdated → save loop.
    }

    private func setupReviewSaveSubscriptions() {
        // .dropFirst() skips the current value emitted immediately on subscription
        // (the already-loaded text). Only actual user edits after this point trigger saves.
        titleViewModel.$text
            .dropFirst()
            .removeDuplicates()
            .debounce(for: .seconds(0.8), scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.persistReviewDataIfNeeded() }
            .store(in: &cancellables)

        notesViewModel.$text
            .dropFirst()
            .removeDuplicates()
            .debounce(for: .seconds(0.8), scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.persistReviewDataIfNeeded() }
            .store(in: &cancellables)

        temperatureViewModel.$text
            .dropFirst()
            .removeDuplicates()
            .debounce(for: .seconds(0.8), scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.persistReviewDataIfNeeded() }
            .store(in: &cancellables)
    }

    private func persistReviewDataIfNeeded() {
        guard isWorkoutLoaded,
              mode == .review,
              let workout = state.currentWorkout,
              let modelContext = SQAppState.shared.modelContext else { return }

        let titleText = titleViewModel.text.trimmingCharacters(in: .whitespacesAndNewlines)
        let temperatureFahrenheit = Double(temperatureViewModel.text.trimmingCharacters(in: .whitespacesAndNewlines))
        let temperatureCelsius = temperatureFahrenheit.flatMap {
            SQUnit.degreesFahrenheit.convert($0, to: .degreesCelsius)
        }
        workout.setReviewData(
            notes: notesViewModel.text.isEmpty ? nil : notesViewModel.text,
            ratingUserPerformance: selectedPerformance?.ratingValue,
            ratingDifficulty: selectedDifficulty?.ratingValue,
            temperature: temperatureCelsius
        )
        // Update title separately since it lives on the session directly
        if let session = workout as? SQWorkoutSession {
            session.title = titleText.isEmpty ? nil : titleText
        }

        Task {
            do {
                try await workoutManager.saveWorkout(workout: workout, to: modelContext, saveToCloud: true)
                state.hub.workoutEvents.send(.workoutsUpdated([workout.id: workout]))
            } catch {
                SQLogger.shared.log(
                    "Failed to save review data: \(error.localizedDescription)",
                    .error,
                    context: .workoutSummary
                )
            }
        }
    }

}

// MARK: - Route Handling

extension SQWorkoutSummaryController {

    func loadRouteIfNeeded() async {
        guard !state.isLoadingRoute, state.routeLocations.isEmpty else { return }
        guard case .hkWorkout(let hk) = state.currentWorkout?.workoutSource else { return }

        state.isLoadingRoute = true
        state.routeLoadErrorMessage = nil

        do {
            let raw = try await healthKitManager.fetchRouteLocations(for: hk.hkWorkout)
            let reduced = downsample(raw, maxPoints: 1500).sorted { $0.timestamp < $1.timestamp }
            state.routeLocations = reduced
        } catch {
            state.routeLoadErrorMessage = error.localizedDescription
            state.routeLocations = []
        }

        state.isLoadingRoute = false
    }

    private func downsample(_ locations: [CLLocation], maxPoints: Int = 1500) -> [CLLocation] {
        guard locations.count > maxPoints else { return locations }
        let stride = max(1, locations.count / maxPoints)
        return locations.enumerated().compactMap { (i, loc) in
            (i % stride == 0) ? loc : nil
        }
    }
}

// MARK: - Performance Handling

extension SQWorkoutSummaryController {

    func loadPerformanceDataIfNeeded(workout: SQWorkoutSessionable) async {
        let rows = await statsManager.loadPerformanceData(for: workout)
        if !rows.isEmpty {
            state.loadPerformanceData(rowData: rows)
        }
    }
}
