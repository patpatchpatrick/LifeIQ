//
//  SQWorkoutsListViewModel.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 12/6/25.
//

import SwiftUI
import Combine
import BeastFitnessCore

@MainActor
protocol SQWorkoutsListInterface {
}

@Observable @MainActor
final class SQWorkoutsListController: SQWorkoutsListInterface {
    private var cancellables = Set<AnyCancellable>()
    private(set) var hasLoadedUI = false
    private let hub: EventHub
    private var allWorkouts: [SQWorkoutSessionable]
    private(set) var rows: [SQWorkoutsListItemViewModel]
    let timeRangeMenuViewModel: SQDropDownMenuViewModel?
    var selectedTimeRange: AppTimeRange? {
        didSet {
            rebuildRows()
        }
    }
    
    init(
        eventHub: EventHub,
        workouts: [SQWorkoutSessionable] = [],
        initialTimeRange: AppTimeRange? = nil
    ) {
        self.hub = eventHub
        self.allWorkouts = workouts
        self.selectedTimeRange = initialTimeRange
        self.rows = []

        if let initialTimeRange {
            let items = AppTimeRange.allCases
                .sorted(by: { $0.sortOrder < $1.sortOrder })
                .map { SQDropDownMenuViewModel.Item(title: $0.rawValue) }
            self.timeRangeMenuViewModel = SQDropDownMenuViewModel(
                defaultItem: .init(title: initialTimeRange.rawValue),
                items: items,
                itemSelectionHandler: { _ in }
            )
        } else {
            self.timeRangeMenuViewModel = nil
        }

        self.timeRangeMenuViewModel?.itemSelectionHandler = { [weak self] selectedTitle in
            guard let self,
                  let selectedRange = AppTimeRange.allCases.first(where: { $0.rawValue == selectedTitle }) else {
                return
            }
            self.selectedTimeRange = selectedRange
        }

        rebuildRows()
        handleEventSubscriptions(hub: eventHub)
    }

    var rangeSubtitle: String {
        selectedTimeRange?.rawValue ?? "Newest first"
    }
    
    private func handleEventSubscriptions(hub: EventHub) {
        hub.workoutEvents.sink { [weak self] event in
            guard let self else { return }
            switch event {
            case .workoutsUpdated(let workoutMap):
                allWorkouts = allWorkouts.map { workout in
                    workoutMap[workout.id] ?? workout
                }
                rebuildRows()
            case .workoutsDeleted(let workoutMap):
                allWorkouts = allWorkouts.filter { workoutMap[$0.id] == nil }
                rebuildRows()
            case .activeWorkoutUpdate:
                break
            }
        }.store(in: &cancellables)
    }

    private func rebuildRows() {
        let visibleWorkouts = filteredWorkouts()
        rows = visibleWorkouts
            .sorted(by: { ($0.startDate ?? .distantPast) > ($1.startDate ?? .distantPast) })
            .map { .init(workout: $0) }
    }

    private func filteredWorkouts() -> [SQWorkoutSessionable] {
        guard let selectedTimeRange else { return allWorkouts }
        let timeRange = selectedTimeRange.sqTimeRange
        return allWorkouts.filter { workout in
            guard let startDate = workout.startDate else { return false }
            return startDate >= timeRange.startDate && startDate <= timeRange.endDate
        }
    }
    
    func displayWorkoutSummary(for row: SQWorkoutsListItemViewModel) {
        hub.domainEvents.send(.pushDashboardRoute(.workoutSummary(controller: .init(workout: row.workout))))
    }
    
    func pushEditWorkoutView(for workout: SQWorkoutSessionable) {
        hub.domainEvents.send(.pushDashboardRoute(.editWorkout(workout: workout)))
    }
}
