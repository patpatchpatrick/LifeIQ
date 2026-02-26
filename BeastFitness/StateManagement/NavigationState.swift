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
    var dashboardNavPath: NavigationPath { get set }
    var selectedTab: NavigationState.Tab { get }
    var selectedTabPublisher: AnyPublisher<NavigationState.Tab, Never> { get }
    func changeTab(to tab: NavigationState.Tab)
    
    var isSettingsSheetVisible: Bool { get }
    func toggleSettingsSheetVisibility(_ isVisible: Bool)
}

@MainActor
@Observable final class NavigationState: NavigationStating {
    private let hub: EventHub
    private var cancellables = Set<AnyCancellable>()
    
    private(set) var isSettingsSheetVisible: Bool = false
    
    var dashboardNavPath: NavigationPath = NavigationPath()
    
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
            case .displaySettings:
                toggleSettingsSheetVisibility(true)
            case .pushDashboardRoute(let route):
                dashboardNavPath.append(route)
            case .popDashboardRoute:
                if !dashboardNavPath.isEmpty {
                    dashboardNavPath.removeLast()
                }
            }
            
        }.store(in: &cancellables)
    }
    
    func changeTab(to tab: Tab) {
        hub.domainEvents.send(.changeTab(tab))
    }
    
    func toggleSettingsSheetVisibility(_ isVisible: Bool) {
        isSettingsSheetVisible = isVisible
    }
}

struct SQNavRoute {
    enum DashboardRoute: Hashable, Equatable {
        case workoutsList(workouts: [SQWorkoutSessionable])
        case workoutView(workout: SQWorkoutSessionable)
        case editWorkout(workout: SQWorkoutSessionable)
        
        var id: String {
            switch self {
            case .workoutsList(workouts: let workouts):
                let workoutsIds = workouts.map(\.id).joined(separator: ",")
                return "workoutsList-\(workoutsIds)"
            case .workoutView(let workout):
                return "workoutView-\(workout.id)"
            case .editWorkout(let workout):
                return "editWorkout-\(workout.id)"
            }
        }
        
        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }
        
        static func == (lhs: DashboardRoute, rhs: DashboardRoute) -> Bool {
            lhs.id == rhs.id
        }
    }
    
    enum Settings: Hashable {
        case nested
    }
}
