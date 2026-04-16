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

struct SQWorkoutHeartRateZonesViewModel {
    struct ZoneItem: Identifiable {
        let id: String
        let zone: SQHeartRateZone
        let title: String
        let subtitle: String
        let durationSeconds: Double
        let contribution: Double
        let rangeText: String
        let color: SQColor
    }

    let title: String
    let subtitle: String
    let averageHeartRateText: String
    let minimumHeartRateText: String
    let maximumHeartRateText: String
    let zoneItems: [ZoneItem]
    let footnote: String
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
    var premiumInsightsModel: SQWorkoutPremiumInsightsModel?

    let navigationTitle: String
    private var cancellables = Set<AnyCancellable>()
    private var isWorkoutLoaded = false
    private var hasTrackedSummaryView = false
    private var hasTrackedReviewSubmission = false
    private var hasPresentedReviewSaveError = false

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
    private let heartRateService: SQHeartRateServicing
    private let statsManager: SQWorkoutStatsManaging
    private let workoutScoreService: SQWorkoutScoreServicing
    private let userState: SQUserStating
    private let workout: SQWorkoutSessionable
    var heartRateZonesViewModel: SQWorkoutHeartRateZonesViewModel?
    
    var navTitle: String {
        switch mode {
        case .standard: return state.workoutTitle ?? workout.visibleTitle
        case .review: return "Nice workout! 💪"
        }
    }
    let showNavEditWorkoutButton: Bool
    var canEditWorkoutMetadata: Bool { userState.isLoggedIn }

    init(
        workoutManager: SQWorkoutManaging = SQWorkoutManager.shared,
        healthKitManager: SQHealthKitManaging = SQHealthKitManager.shared,
        statsManager: SQWorkoutStatsManaging = SQWorkoutStatsManager.shared,
        workoutScoreService: SQWorkoutScoreServicing? = nil,
        userState: SQUserStating = SQAppState.shared.userState,
        workout: SQWorkoutSessionable,
        mode: SQWorkoutSummaryMode = .standard
    ) {
        let resolvedHeartRateService = SQHeartRateService(healthKitManager: healthKitManager)

        self.state = WorkoutSummaryState(hub: SQAppState.shared.hub)
        self.workoutManager = workoutManager
        self.healthKitManager = healthKitManager
        self.heartRateService = resolvedHeartRateService
        self.workout = workout
        self.statsManager = statsManager
        self.userState = userState
        self.workoutScoreService = workoutScoreService ?? SQWorkoutScoreService(
            heartRateService: resolvedHeartRateService
        )
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

        self.temperatureViewModel.setPlaceholder(temperaturePlaceholder)
        
        setupEventSubscriptions()
    }

    var temperatureUnit: SQUnit {
        SQUnitSystemResolver.resolve(for: userState.loggedInUser).temperatureUnit
    }

    private var temperaturePlaceholder: String {
        switch temperatureUnit {
        case .degreesCelsius:
            return "22"
        case .degreesFahrenheit:
            return "72"
        default:
            return "22"
        }
    }
    
    func onAppear() async {
        temperatureViewModel.setPlaceholder(temperaturePlaceholder)
        await load(workout: workout)
    }

    private var hasLoaded = false
    private func load(workout: any SQWorkoutSessionable) async {
        guard !hasLoaded else { return }
        hasLoaded = true
        state.isLoading = true
        state.reset()
        heartRateZonesViewModel = nil
        await state.load(workout: workout)
        await loadRouteIfNeeded()
        await loadHeartRateZonesIfNeeded(workout: workout)
        await loadPerformanceDataIfNeeded(workout: workout)
        await loadPremiumInsightsIfNeeded(workout: workout)
        state.isLoading = false

        if mode == .review {
            titleViewModel.setText(workout.visibleTitle)
            notesViewModel.initializeText(workout.reviewNotes ?? "")
            // Temperature: prefer stored value, then try HealthKit metadata
            let roundedTemperatureDecimalPlaces = 0
            if let stored = workout.temperatureCelsius,
               let displayTemperature = SQUnit.degreesCelsius.convert(stored, to: temperatureUnit) {
                temperatureViewModel.setText(displayTemperature.sqStringRoundedTo(places: roundedTemperatureDecimalPlaces))
            } else if case .hkWorkout(let hk) = workout.workoutSource,
                      let celsius = healthKitManager.weatherTemperatureCelsius(from: hk.hkWorkout),
                      let displayTemperature = SQUnit.degreesCelsius.convert(celsius, to: temperatureUnit) {
                temperatureViewModel.setText(displayTemperature.sqStringRoundedTo(places: roundedTemperatureDecimalPlaces))
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
        if !hasTrackedSummaryView {
            hasTrackedSummaryView = true
            SQAnalyticsManager.shared.track(.workoutSummaryViewed(
                workout: workout,
                entryMode: mode == .review ? "review" : "standard"
            ))
        }
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

        SQAnalyticsManager.shared.track(.leaderboardOpened(mode: mode, sourceScreen: "workout_summary"))

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
        guard canEditWorkoutMetadata else {
            presentWorkoutEditingLoginFlow()
            return
        }

        guard let baseWorkout = state.currentWorkout else {
            SQLogger.shared.log("Workout missing. Can't push edit workout screen.", .error, context: .workoutSummary)
            return
        }

        SQAnalyticsManager.shared.track(.workoutEditTapped(
            workout: baseWorkout,
            sourceScreen: "workout_summary"
        ))
        state.hub.domainEvents.send(.pushDashboardRoute(.editWorkout(workout: baseWorkout)))
    }

    func displayPremiumInsightDetail(for score: SQWorkoutPremiumInsightScore) {
        SQAnalyticsManager.shared.track(.insightOpened(
            insightId: score.id,
            insightType: score.kind.rawValue.analyticsKey,
            sourceScreen: "workout_summary",
            insightCategory: "workout_score"
        ))
        let controller = SQWorkoutInsightDetailController(model: score.detailModel)
        state.hub.domainEvents.send(.pushDashboardRoute(.workoutInsightDetail(controller: controller)))
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

        SQAnalyticsManager.shared.track(.workoutDeleteTapped(
            workout: baseWorkout,
            sourceScreen: "workout_summary"
        ))

        state.hub.alertEvents.send(.present(.init(
            title: title,
            subtitle: subtitle,
            primary: .init(title: "Delete workout?", handler: { _ in
                Task { [weak self] in
                    guard let self else { return }
                    do {
                        try await self.workoutManager.deleteWorkout(workout: baseWorkout, from: modelContext)
                        SQAnalyticsManager.shared.track(.workoutDeleted(
                            workout: baseWorkout,
                            sourceScreen: "workout_summary"
                        ))
                        self.state.notifyAppOfWorkoutDeletion(workout: baseWorkout)
                        self.state.hub.domainEvents.send(.popDashboardRoute)
                    } catch {
                        self.state.hub.alertEvents.send(.present(.init(error as? SQUserFacingError ?? SQError.standard)))
                    }
                }
            }),
            secondary: .init(title: "Cancel", role: .cancel))))
    }
}

// MARK: - Review Persistence

extension SQWorkoutSummaryController {
    func presentWorkoutEditingLoginFlow() {
        let controller = SQProfileController(userState: userState)
        state.hub.domainEvents.send(.pushDashboardRoute(.profile(controller: controller)))
    }

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
              canEditWorkoutMetadata,
              let workout = state.currentWorkout,
              let modelContext = SQAppState.shared.modelContext else { return }

        let titleText = titleViewModel.text.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayTemperature = Double(temperatureViewModel.text.trimmingCharacters(in: .whitespacesAndNewlines))
        let temperatureCelsius = temperatureUnit.convert(displayTemperature, to: .degreesCelsius)
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

        Task { [weak self] in
            guard let self else { return }
            do {
                try await self.workoutManager.saveWorkout(workout: workout, to: modelContext, saveToCloud: true)
                self.hasPresentedReviewSaveError = false
                if !self.hasTrackedReviewSubmission {
                    let hasWeather = temperatureCelsius != nil
                    let hasPerformanceScore = self.selectedPerformance?.ratingValue != nil
                    let hasDifficultyScore = self.selectedDifficulty?.ratingValue != nil
                    let hasNotes = !(self.notesViewModel.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    if hasWeather || hasPerformanceScore || hasDifficultyScore || hasNotes {
                        self.hasTrackedReviewSubmission = true
                        SQAnalyticsManager.shared.track(.workoutReviewSubmitted(
                            workout: workout,
                            hasWeather: hasWeather,
                            hasPerformanceScore: hasPerformanceScore,
                            hasDifficultyScore: hasDifficultyScore,
                            hasNotes: hasNotes
                        ))
                    }
                }
                self.state.hub.workoutEvents.send(.workoutsUpdated([workout.id: workout]))
            } catch {
                SQLogger.shared.log(
                    "Failed to save review data: \(error.localizedDescription)",
                    .error,
                    context: .workoutSummary
                )
                if !self.hasPresentedReviewSaveError {
                    self.hasPresentedReviewSaveError = true
                    self.state.hub.alertEvents.send(
                        .present(.init(SQError.standard(withDescription: "Error saving workout review: \(error.localizedDescription)")))
                    )
                }
            }
        }
    }

}

// MARK: - Route Handling

extension SQWorkoutSummaryController {

    func loadHeartRateZonesIfNeeded(workout: SQWorkoutSessionable) async {
        guard let summary = await heartRateService.buildWorkoutZoneSummary(for: workout) else {
            heartRateZonesViewModel = nil
            return
        }

        heartRateZonesViewModel = .init(
            title: "Heart Rate Zones",
            subtitle: "Time spent in each zone during this workout.",
            averageHeartRateText: "\(Int(summary.averageHeartRate.rounded())) bpm",
            minimumHeartRateText: "\(Int(summary.minimumObservedHeartRate.rounded())) bpm",
            maximumHeartRateText: "\(Int(summary.maximumObservedHeartRate.rounded())) bpm",
            zoneItems: summary.distributions.map { distribution in
                .init(
                    id: distribution.zone.title,
                    zone: distribution.zone,
                    title: distribution.zone.title,
                    subtitle: distribution.zone.subtitle,
                    durationSeconds: distribution.durationSeconds,
                    contribution: distribution.contribution,
                    rangeText: rangeText(for: distribution.range),
                    color: accentColor(for: distribution.zone)
                )
            },
            footnote: "Zones are estimated from your profile age and observed workout heart rate. Harder zones contribute more to difficulty."
        )
    }

    func loadPremiumInsightsIfNeeded(workout: SQWorkoutSessionable) async {
        guard let modelContext = SQAppState.shared.modelContext else {
            premiumInsightsModel = nil
            return
        }

        do {
            let allTimeWorkouts = try await workoutManager.getWorkouts(for: .allTime, modelContext: modelContext)
            premiumInsightsModel = await workoutScoreService.insights(
                for: workout,
                allTimeWorkouts: allTimeWorkouts,
                isPremiumUnlocked: SQAppState.shared.userState.loggedInUser?.hasPremiumAccess ?? true
            )
        } catch {
            premiumInsightsModel = nil
            SQLogger.shared.log(
                "Failed to load premium workout insights: \(error.localizedDescription)",
                .debug,
                context: .workoutSummary
            )
        }
    }

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
        let rows = await statsManager.loadPerformanceData(
            for: workout,
            isPremiumUnlocked: SQAppState.shared.userState.loggedInUser?.hasPremiumAccess ?? true
        )
        if !rows.isEmpty {
            state.loadPerformanceData(rowData: rows)
        }
    }
}

private extension SQWorkoutSummaryController {
    func accentColor(for zone: SQHeartRateZone) -> SQColor {
        switch zone {
        case .zone1:
            return .accentNeutral4
        case .zone2:
            return .dashboardGlowMint
        case .zone3:
            return .dashboardGlowBlue
        case .zone4:
            return .dashboardTrendWarm
        case .zone5:
            return .accentNeutral1
        }
    }

    func rangeText(for range: SQHeartRateZoneRange) -> String {
        if let upperBound = range.upperBound {
            return "\(range.lowerBound)-\(upperBound - 1) bpm"
        }

        return "\(range.lowerBound)+ bpm"
    }
}
