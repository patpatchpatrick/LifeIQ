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

@MainActor
protocol SQWorkoutSummaryInterface {
    func load(workout: SQWorkoutSessionable) async
    func pushEditWorkoutView()
}

@Observable @MainActor
final class SQWorkoutSummaryController: SQWorkoutSummaryInterface {
    let state: WorkoutSummaryStating
    private let workoutManager: SQWorkoutManaging
    private let healthKitManager: SQHealthKitManaging
    var onPushEditWorkoutView: (SQWorkoutSessionable) -> Void
    var onDismiss: () -> Void
    
    @MainActor
    static func `default`(workout: any SQWorkoutSessionable, onPushEditWorkoutView: @escaping (SQWorkoutSessionable) -> Void, onDismiss: @escaping () -> Void) -> SQWorkoutSummaryController {
        Self.default.onPushEditWorkoutView = onPushEditWorkoutView
        Self.default.onDismiss = onDismiss
        Task {
            await Self.default.load(workout: workout)
        }
        return Self.default
    }
    
    @MainActor
    static let `default`: SQWorkoutSummaryController = SQWorkoutSummaryController(state: SQAppState.shared.workoutSummaryState, onPushEditWorkoutView: { _ in }, onDismiss: {})

    init(state: WorkoutSummaryStating, workoutManager: SQWorkoutManaging = SQWorkoutManager(), healthKitManager: SQHealthKitManaging = SQHealthKitManager(), onPushEditWorkoutView: @escaping (SQWorkoutSessionable) -> Void, onDismiss: @escaping () -> Void) {
        self.state = state
        self.workoutManager = workoutManager
        self.healthKitManager = healthKitManager
        self.onPushEditWorkoutView = onPushEditWorkoutView
        self.onDismiss = onDismiss
    }
    
    func load(workout: any SQWorkoutSessionable) async {
        state.reset()
        await state.load(workout: workout)
        await loadRouteIfNeeded()
        await loadPerformanceDataIfNeeded(workout: workout)
    }
    
    func pushEditWorkoutView() {
        guard let baseWorkout = state.currentWorkout else {
            SQLogger.shared.log("Workout missing. Can't push edit workout screen.", .error, context: .workoutSummary)
            return
        }
        
        onPushEditWorkoutView(baseWorkout)
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
                        onDismiss()
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

            // Do reduction off-main (cheap, but keep it off your UI actor anyway)
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
        guard workout.activityType.impactsVO2MaxData else { return }
        guard let workoutEndDate = workout.endDate else { return }
        do {
            // Fetch the most recent VO2 max sample recorded up to the workout's end date
            let daySamples = try await healthKitManager.fetchVO2MaxSamples(upTo: workoutEndDate, limit: 1)
            guard let sample = daySamples.first else { return }

            // Fetch all-time values for percentile ranking, deduped by calendar day
            let allTimeSamples = try await healthKitManager.fetchVO2MaxSamples(.allTime)
            let calendar = Calendar.current
            var bestByDay: [Date: Double] = [:]
            for s in allTimeSamples {
                let dayStart = calendar.startOfDay(for: s.startDate)
                bestByDay[dayStart] = max(bestByDay[dayStart] ?? 0, s.value)
            }
            let historicalValues = Array(bestByDay.values)

            let percentileRank = SQPercentileCalculator.calculatePercentile(
                currentBest: sample.value,
                historicalValues: historicalValues,
                isLowerBetter: false
            )

            let rowData = SQPerformanceRowData(
                id: "vo2-max",
                icon: SQImageSymbol.heart.rawValue,
                title: "VO2 Max",
                bestValue: String(format: "%.1f", sample.value),
                unit: "mL/kg/min",
                percentileRank: percentileRank
            )

            state.loadPerformanceData(rowData: [rowData])
        } catch {
            SQLogger.shared.log(
                "Failed to load VO2 max for performance section: \(error.localizedDescription)",
                .error,
                context: .workoutSummary
            )
        }
    }
}
