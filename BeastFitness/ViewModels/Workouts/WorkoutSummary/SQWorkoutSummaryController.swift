//
//  SQWorkoutSummaryView.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 12/6/25.
//

import SwiftUI
import SwiftData
import BeastFitnessCore
import CoreLocation
import HealthKit

enum SQWorkoutSummaryMode: Equatable {
    case standard
    case review
}

struct SQWorkoutReviewHighlight: Identifiable {
    let id = UUID()
    let text: String
    let sentiment: Sentiment

    enum Sentiment {
        case positive, neutral, negative
    }
}

@MainActor
protocol SQWorkoutSummaryInterface {
    func pushEditWorkoutView()
}

@Observable @MainActor
final class SQWorkoutSummaryController: SQWorkoutSummaryInterface {
    let id = UUID().uuidString
    let state: WorkoutSummaryStating
    private let workoutManager: SQWorkoutManaging
    private let healthKitManager: SQHealthKitManaging

    init(workoutManager: SQWorkoutManaging = SQWorkoutManager.shared, healthKitManager: SQHealthKitManaging = SQHealthKitManager.shared, workout: SQWorkoutSessionable) {
        self.state = WorkoutSummaryState(hub: SQAppState.shared.hub)
        self.workoutManager = workoutManager
        self.healthKitManager = healthKitManager
        Task {
            await load(workout: workout)
        }
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
        guard case .hkWorkout = workout.workoutSource else { return }
        guard let workoutEndDate = workout.endDate else { return }
        guard let modelContext = SQAppState.shared.modelContext else { return }

        var rows: [SQPerformanceRowData] = []

        do {
            let allTimeWorkouts = try await workoutManager.getWorkouts(for: .allTime, modelContext: modelContext)
            let sameActivityWorkouts = allTimeWorkouts.filter { $0.activityType == workout.activityType }
            let activityIcon = workout.activityType.imageSymbol.rawValue

            // VO2 Max — special case, not a workout metric
            if workout.activityType.impactsVO2MaxData {
                let recentSamples = try await healthKitManager.fetchVO2MaxSamples(upTo: workoutEndDate, limit: 1)
                if let sample = recentSamples.first {
                    let allTimeSamples = try await healthKitManager.fetchVO2MaxSamples(.allTime)
                    let calendar = Calendar.current
                    var bestByDay: [Date: Double] = [:]
                    for s in allTimeSamples {
                        let dayStart = calendar.startOfDay(for: s.startDate)
                        bestByDay[dayStart] = max(bestByDay[dayStart] ?? 0, s.value)
                    }
                    let percentile = SQPercentileCalculator.calculatePercentile(
                        currentBest: sample.value,
                        historicalValues: Array(bestByDay.values),
                        isLowerBetter: false
                    )
                    rows.append(SQPerformanceRowData(
                        id: "vo2-max",
                        icon: SQImageSymbol.heart.rawValue,
                        title: "VO2 Max",
                        bestValue: String(format: "%.1f", sample.value),
                        unit: "mL/kg/min",
                        percentileRank: percentile,
                        leaderboardMode: .vo2Max
                    ))
                }
            }

            // Workout metrics — same pattern as SQDashboardController
            let metricTypes = workoutManager.metrics(for: workout.activityType)
            for quantityType in metricTypes {
                guard let currentMetric = await workout.getMetric(for: quantityType) else { continue }

                let historicalValues = await withTaskGroup(of: Double?.self) { group in
                    for w in sameActivityWorkouts {
                        group.addTask { await w.getMetric(for: quantityType)?.value }
                    }
                    var results: [Double] = []
                    for await value in group { if let v = value { results.append(v) } }
                    return results
                }

                let isLowerBetter = quantityType.dashboardAggregationType == .minimum
                let percentile = SQPercentileCalculator.calculatePercentile(
                    currentBest: currentMetric.value,
                    historicalValues: historicalValues,
                    isLowerBetter: isLowerBetter
                )

                rows.append(SQPerformanceRowData(
                    id: "\(workout.activityType.name.lowercased())-\(quantityType.id)",
                    icon: activityIcon,
                    title: currentMetric.displayName,
                    bestValue: currentMetric.displayableValue(for: quantityType, value: currentMetric.value),
                    unit: currentMetric.unit.unitString ?? "",
                    percentileRank: percentile,
                    leaderboardMode: .workoutQuantity(quantityType, workout.activityType)
                ))
            }

        } catch {
            SQLogger.shared.log(
                "Failed to load performance data: \(error.localizedDescription)",
                .error,
                context: .workoutSummary
            )
        }

        if !rows.isEmpty {
            state.loadPerformanceData(rowData: rows)
        }
    }
}
