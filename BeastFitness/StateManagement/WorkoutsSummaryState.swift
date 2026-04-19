//
//  WorkoutsSummaryState.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 12/8/25.
//


import SwiftUI
import Combine
import BeastFitnessCore
import CoreLocation

@MainActor
protocol WorkoutSummaryStating: AnyObject {
    var isLoading: Bool { get set }
    var shouldReactToWorkoutUpdates: Bool { get set }
    var hub: EventHub { get }
    var user: SQUser? { get }
    var userFullName: String? { get }
    var isLoggedIn: Bool { get }
    var workoutStartDate: Date? { get }
    var workoutTitle: String? { get }
    var workoutStatsRows: [SQPerformanceRowData] { get }
    var workoutStatRowColumnCount: Int { get }

    var currentWorkout: SQWorkoutSessionable? { get }
    func load(workout: SQWorkoutSessionable) async
    func reset()
    func notifyAppOfWorkoutDeletion(workout: SQWorkoutSessionable)

    var isLoadingRoute: Bool { get set  }
    var routeLocations: [CLLocation] { get set }
    var routeLoadErrorMessage: String? { get set }
    var shouldShowRouteView: Bool { get }

    var hasRoute: Bool { get }

    var performanceRowData: [SQPerformanceRowData] { get }
    var shouldShowPerformanceSection: Bool { get }
    func loadPerformanceData(rowData: [SQPerformanceRowData])
}

@MainActor
@Observable final class WorkoutSummaryState: WorkoutSummaryStating {
    let hub: EventHub
    private let userState: SQUserStating
    private var cancellables = Set<AnyCancellable>()

    private(set) var currentWorkout: (any SQWorkoutSessionable)?
    private(set) var user: SQUser?
    private(set) var userFullName: String?
    private(set) var isLoggedIn: Bool = false
    private(set) var workoutStartDate: Date?
    private(set) var workoutTitle: String?
    private(set) var workoutStatsRows: [SQPerformanceRowData] = []
    private(set) var workoutStatRowColumnCount: Int = 2

    var isLoading: Bool = true
    var isLoadingRoute: Bool = false
    /// Set to false when this controller is the source of saves (e.g. review mode),
    /// so it doesn't reload itself in response to its own workoutsUpdated events.
    var shouldReactToWorkoutUpdates: Bool = true
    var routeLocations: [CLLocation] = []
    var routeLoadErrorMessage: String? = nil
    var hasRoute: Bool { !routeLocations.isEmpty }

    private(set) var performanceRowData: [SQPerformanceRowData] = []

    var shouldShowPerformanceSection: Bool { !performanceRowData.isEmpty }

    init(hub: EventHub, userState: SQUserStating = SQAppState.shared.userState) {
        self.hub = hub
        self.userState = userState
        updateUserContext()
        handleEventSubscriptions()
    }

    private func handleEventSubscriptions() {
        hub.workoutEvents.sink { [weak self] event in
            guard let self else { return }
            switch event {
            case .workoutsUpdated(let workoutMap):
                if shouldReactToWorkoutUpdates, let currentWorkoutId = currentWorkout?.id, let updatedWorkout = workoutMap[currentWorkoutId] {
                    SQLogger.shared.log("Refreshing workout summary with id: \(updatedWorkout.id) and title: \(String(describing: updatedWorkout.title))", .debug, context: .workoutSummary)
                    Task {
                        await self.load(workout: updatedWorkout)
                    }
                }
            case .workoutsDeleted, .activeWorkoutUpdate:
                return
            }

        }.store(in: &cancellables)

        hub.userEvents.sink { [weak self] event in
            guard let self else { return }
            switch event {
            case .loginStateChanged, .emailVerificationStateChanged, .profileUpdated:
                updateUserContext()
            }
        }.store(in: &cancellables)
    }

    private func updateUserContext() {
        user = userState.loggedInUser
        userFullName = user?.fullName
        isLoggedIn = userState.isLoggedIn
    }

    func load(workout: any SQWorkoutSessionable) async {
        SQLogger.shared.log("Loading workout summary with workout with id: \(workout.id) and title: \(String(describing: workout.title))", .debug, context: .workoutSummary)
        currentWorkout = workout
        updateUserContext()
        workoutStartDate = workout.startDate
        workoutTitle = workout.visibleTitle

        let visibleStats = await workout.visibleStats() ?? []
        workoutStatsRows = visibleStats.map { .init(id: $0.id.uuidString, icon: $0.icon, title: $0.title, bestValue: $0.value, unit: "", percentileRank: nil) }
    }

    func reset() {
        routeLocations = []
        isLoadingRoute = false
        
        currentWorkout = nil
        updateUserContext()
        workoutStartDate = nil
        workoutTitle = nil
        workoutStatsRows = []
        performanceRowData = []
    }

    func loadPerformanceData(rowData: [SQPerformanceRowData]) {
        performanceRowData = rowData
    }

    func notifyAppOfWorkoutDeletion(workout: SQWorkoutSessionable) {
        hub.workoutEvents.send(.workoutsDeleted([workout.id: workout]))
    }


    /// Whether the summary UI should include the route map section.
    var shouldShowRouteView: Bool {
        guard let workout = currentWorkout else { return false }

        // Only HealthKit workouts can have HKWorkoutRoute
        guard case .hkWorkout = workout.workoutSource else { return false }

        // Don't show an empty "No route" card for workouts where route is irrelevant,
        // unless we're actively loading or we already know there is a route/error.
        if isLoadingRoute || hasRoute || routeLoadErrorMessage != nil {
            return true
        }

        switch workout.activityType {
        case .running, .walking, .cycling, .hiking:
            return true
        default:
            return false
        }
    }
}

struct SQWorkoutSummaryStatRow: Identifiable {
    let id = UUID()
    let visibleStats: [SQWorkoutSessionVisibleStat]
}
