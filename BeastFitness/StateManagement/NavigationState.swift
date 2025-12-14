//
//  NavigationState.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 11/11/25.
//

import SwiftUI
import Combine

@MainActor
protocol NavigationStating: AnyObject {
    var selectedTab: NavigationState.Tab { get }
    var selectedTabPublisher: AnyPublisher<NavigationState.Tab, Never> { get }
    func changeTab(to tab: NavigationState.Tab)
}

@MainActor
@Observable final class NavigationState: NavigationStating {
    private let hub: EventHub
    private var cancellables = Set<AnyCancellable>()
    
    enum Tab: Hashable {
        case home
        case workouts
    }
    
    @ObservationIgnored private let selectedTabSubject = PassthroughSubject<Tab, Never>()
    var selectedTab: Tab { didSet { selectedTabSubject.send(selectedTab) } }
    var selectedTabPublisher: AnyPublisher<Tab, Never> { selectedTabSubject.eraseToAnyPublisher() }
    
    init(hub: EventHub) {
        self.hub = hub
        self.selectedTab = .home
        
        hub.domainEvents.sink { [weak self] event in
            guard let self else { return }
            switch event {
            case .changeTab(let tab):
                if tab != self.selectedTab {
                    self.selectedTab = tab
                }
            }
            
        }.store(in: &cancellables)
    }
    
    func changeTab(to tab: Tab) {
        hub.domainEvents.send(.changeTab(tab))
    }
}

struct SQNavRoute {
    enum WorkoutsList: Hashable, Equatable {
        case workoutView(workout: SQWorkoutSessionable)
        case editWorkout(workout: SQWorkoutSessionable)
        
        func hash(into hasher: inout Hasher) {
            switch self {
            case .workoutView(let workout):
                hasher.combine("workoutView-\(workout.id)")
            case .editWorkout(let workout):
                hasher.combine("editWorkout-\(workout.id)")
            }
        }
        
        static func == (lhs: WorkoutsList, rhs: WorkoutsList) -> Bool {
            switch (lhs, rhs) {
            case (.workoutView(let lhs), .workoutView(let rhs)):
                return lhs.id == rhs.id
            case (.editWorkout(let lhs), .editWorkout(let rhs)):
                return lhs.id == rhs.id
            default:
                return false
            }
        }
    }
}
