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
}

@MainActor
@Observable final class NavigationState: NavigationStating {
    private let hub: EventHub
    private var cancellables = Set<AnyCancellable>()
    
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
    
}

struct SQNavRoute {
    enum DashboardRoute: Identifiable, Hashable, Equatable {
        case workoutsList(workouts: [SQWorkoutSessionable])
        case workoutSummary(controller: SQWorkoutSummaryController)
        case workoutInsightDetail(controller: SQWorkoutInsightDetailController)
        case insightDetail(model: SQInsight)
        case webContent(title: String, urlString: String)
        case lifeScoreDetail(controller: SQLifeScoreDetailController)
        case recoveryScoreDetail(controller: SQRecoveryScoreDetailController)
        case workoutReview(workouts: [SQWorkoutSessionable])
        case editWorkout(workout: SQWorkoutSessionable)
        case leaderboard(controller: SQLeaderboardController)
        case sleepPhaseTrends(controller: SQSleepPhaseTrendsController)
        case launchTutorial(controller: SQLaunchTutorialController)
        case metricDetail(controller: SQMetricDetailController)
        case profile(controller: SQProfileController)
        case login(controller: SQLoginController)
        case deleteAccount(controller: SQDeleteAccountController)
        case onboarding(controller: SQOnboardingController)
        case settings(controller: SQSettingsController)
        case dashboardLayout(controller: SQDashboardLayoutController)
        case dashboardSubsectionLayout(controller: SQDashboardLayoutController, groupId: String)
        case viewLab(controller: SQViewLabController)
        
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
            case .workoutInsightDetail(let controller):
                return "workoutInsightDetail-\(controller.id)"
            case .insightDetail(let model):
                return "insightDetail-\(model.id)"
            case .webContent(let title, let urlString):
                return "webContent-\(title)-\(urlString)"
            case .lifeScoreDetail(let controller):
                return "lifeScoreDetail-\(controller.id)"
            case .recoveryScoreDetail(let controller):
                return "recoveryScoreDetail-\(controller.id)"
            case .editWorkout(let workout):
                return "editWorkout-\(workout.id)"
            case .leaderboard(controller: let controller):
                return "leaderboard-\(controller.id)"
            case .sleepPhaseTrends(controller: let controller):
                return "sleepPhaseTrends-\(controller.id)"
            case .launchTutorial(controller: let controller):
                return "launchTutorial-\(controller.id)"
            case .metricDetail(controller: let controller):
                return "metricDetail-\(controller.id)"
            case .profile(let controller):
                return "profile-\(controller.id)"
            case .login(let controller):
                return "login-\(controller.id)"
            case .deleteAccount(let controller):
                return "deleteAccount-\(controller.id)"
            case .onboarding(let controller):
                return "onboarding-\(controller.id)"
            case .settings(let controller):
                return "settings-\(controller.id)"
            case .dashboardLayout(let controller):
                return "dashboardLayout-\(controller.id)"
            case .dashboardSubsectionLayout(let controller, let groupId):
                return "dashboardSubsectionLayout-\(controller.id)-\(groupId)"
            case .viewLab(let controller):
                return "viewLab-\(controller.id)"
            }
        }
        
        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }
        
        static func == (lhs: DashboardRoute, rhs: DashboardRoute) -> Bool {
            lhs.id == rhs.id
        }

        var sheetDetents: Set<PresentationDetent>? {
            switch self {
            case .launchTutorial:
                return [.large]
            case .insightDetail:
                return [.medium, .large]
            case .webContent:
                return [.large]
            case .recoveryScoreDetail:
                return [.medium, .large]
            case .viewLab:
                return [.large]
            default:
                return nil
            }
        }

        var sheetDragIndicatorVisibility: Visibility {
            sheetDetents == nil ? .automatic : .visible
        }
    }
    
    enum Settings: Hashable {
        case nested
    }
}
