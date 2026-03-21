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
    var dashboardNavStack: [SQNavRoute.DashboardRoute] { get }
    var dashboardRootSheetView: SQNavRoute.DashboardRoute? { get set }
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
    
    var dashboardRootSheetView: SQNavRoute.DashboardRoute? {
        didSet {
            if dashboardRootSheetView == nil {
                dashboardNavPath = .init() /// Clear the nav stack if the sheet is dismissed
            }
        }
    }
    let dashboardNavStack = [SQNavRoute.DashboardRoute]()
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
                
                if dashboardRootSheetView == nil {
                    dashboardRootSheetView = route
                } else {
                    dashboardNavPath.append(route)
                }
                
                
            case .popDashboardRoute:
                
                if dashboardNavPath.isEmpty {
                   dashboardRootSheetView = nil
                } else {
                    dashboardNavPath.removeLast()
                }
                
            case .dismissDashboardNavStack:
                
                dashboardRootSheetView = nil
                dashboardNavPath = .init()
                
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
    enum DashboardRoute: Identifiable, Hashable, Equatable {
        case workoutsList(workouts: [SQWorkoutSessionable])
        case workoutSummary(controller: SQWorkoutSummaryController)
        case workoutReview(workouts: [SQWorkoutSessionable])
        case editWorkout(workout: SQWorkoutSessionable)
        case leaderboard(controller: SQLeaderboardController)
        case profile(controller: SQProfileController)
        case login(controller: SQLoginController)
        
        var id: String {
            switch self {
            case .workoutsList(workouts: let workouts):
                let workoutsIds = workouts.map(\.id).joined(separator: ",")
                return "workoutsList-\(workoutsIds)"
            case .workoutReview(workouts: let workouts):
                let workoutsIds = workouts.map(\.id).joined(separator: ",")
                return "workoutReview-\(workoutsIds)"
            case .workoutSummary(let controller):
                return "workoutSummary-\(controller.id)"
            case .editWorkout(let workout):
                return "editWorkout-\(workout.id)"
            case .leaderboard(controller: let controller):
                return "leaderboard-\(controller.id)"
            case .profile(let controller):
                return "profile-\(controller.id)"
            case .login(let controller):
                return "login-\(controller.id)"
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
