//
//  SQEditWorkoutController.swift
//  BeastFitness
//

import SwiftUI
import SwiftData
import Combine
import BeastFitnessCore

@Observable @MainActor
final class SQEditWorkoutController: Identifiable {
    let id = UUID().uuidString
    var dismissKeyboard: Bool = false

    // MARK: - Form ViewModels

    let titleViewModel: SQUITextFieldViewModel
    let notesViewModel: SQTextFieldViewModel = .init(
        axis: .vertical,
        lineLimit: 5,
        placeholder: "How'd it go? Any notes...",
        textAutoCap: .sentences,
        autoCorrectionEnabled: true
    )
    let temperatureViewModel: SQUITextFieldViewModel = SQUITextFieldViewModel(
        placeholder: "Temperature (e.g. 72)",
        font: SQFont(type: .body).uiFont,
        keyboardType: .decimalPad,
        autocapitalizationType: .none,
        autocorrectionType: .no,
        textChangeFormatter: .decimal(maxDecimalPlaces: 1)
    )
    var selectedPerformance: SQSegmentedControlSegment? = nil {
        didSet { persistIfNeeded() }
    }
    var selectedDifficulty: SQSegmentedControlSegment? = nil {
        didSet { persistIfNeeded() }
    }

    // MARK: - Segments

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

    // MARK: - Private

    private let workout: SQWorkoutSessionable
    private let workoutManager: SQWorkoutManaging
    private var cancellables = Set<AnyCancellable>()
    private var isLoaded = false

    // MARK: - Init

    init(
        workout: SQWorkoutSessionable,
        workoutManager: SQWorkoutManaging = SQWorkoutManager.shared
    ) {
        self.workout = workout
        self.workoutManager = workoutManager
        self.titleViewModel = SQUITextFieldViewModel(
            placeholder: workout.visibleTitle,
            font: SQFont(type: .body).uiFont,
            autocapitalizationType: .sentences,
            autocorrectionType: .yes,
            textChangeFormatter: .maxLength(SQWorkoutSession.titleMaxChars)
        )
    }

    // MARK: - Lifecycle

    func onAppear() {
        guard !isLoaded else { return }
        isLoaded = true

        titleViewModel.setText(workout.visibleTitle)
        notesViewModel.initializeText(workout.reviewNotes ?? "")

        let fahrenheitDecimalPlaces = 0
        if let celsius = workout.temperatureCelsius,
           let fahrenheit = SQUnit.degreesCelsius.convert(celsius, to: .degreesFahrenheit) {
            temperatureViewModel.setText(fahrenheit.sqStringRoundedTo(places: fahrenheitDecimalPlaces))
        }

        selectedPerformance = workout.ratingUserPerformance.flatMap { rating in
            Self.performanceSegments.first { $0.ratingValue == rating }
        }
        selectedDifficulty = workout.ratingDifficulty.flatMap { rating in
            Self.difficultySegments.first { $0.ratingValue == rating }
        }

        setupSaveSubscriptions()
    }

    func dismiss() {
        SQAppState.shared.hub.domainEvents.send(.popDashboardRoute)
    }

    // MARK: - Save Subscriptions

    private func setupSaveSubscriptions() {
        titleViewModel.$text
            .dropFirst()
            .removeDuplicates()
            .debounce(for: .seconds(0.8), scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.persistIfNeeded() }
            .store(in: &cancellables)

        notesViewModel.$text
            .dropFirst()
            .removeDuplicates()
            .debounce(for: .seconds(0.8), scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.persistIfNeeded() }
            .store(in: &cancellables)

        temperatureViewModel.$text
            .dropFirst()
            .removeDuplicates()
            .debounce(for: .seconds(0.8), scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.persistIfNeeded() }
            .store(in: &cancellables)
    }

    // MARK: - Persistence

    private func persistIfNeeded() {
        guard isLoaded,
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

        if let session = workout as? SQWorkoutSession {
            session.title = titleText.isEmpty ? nil : titleText
        }

        Task {
            do {
                try await workoutManager.saveWorkout(workout: workout, to: modelContext, saveToCloud: false)
                SQLogger.shared.log("Auto-saved edit workout data", .debug, context: .workoutSession)
            } catch {
                SQLogger.shared.log(
                    "Failed to auto-save edit workout: \(error.localizedDescription)",
                    .error,
                    context: .workoutSession
                )
            }
        }
    }
}
