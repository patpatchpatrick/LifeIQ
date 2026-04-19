//
//  SQLaunchTutorialController.swift
//  BeastFitness
//
//  Created by Codex on 4/19/26.
//

import Foundation
import SwiftUI
import BeastFitnessCore

@MainActor
@Observable final class SQLaunchTutorialController: Identifiable {
    enum Step: Int, CaseIterable {
        case overview
        case healthKit
        case ready
    }

    static let currentVersion = 1

    let id = UUID().uuidString

    private let hub: EventHub
    private let healthKitManager: SQHealthKitManaging
    private let onCompletion: @MainActor (Bool) async -> Void

    var currentStep: Step = .overview
    var isRequestingHealthKitAccess = false
    private(set) var healthKitAccessStatus: SQHealthKitDashboardAccessStatus = .unavailable

    init(
        hub: EventHub = SQAppState.shared.hub,
        healthKitManager: SQHealthKitManaging = SQHealthKitManager.shared,
        onCompletion: @escaping @MainActor (Bool) async -> Void = { _ in }
    ) {
        self.hub = hub
        self.healthKitManager = healthKitManager
        self.onCompletion = onCompletion

        Task { @MainActor [weak self] in
            await self?.refreshHealthKitAccessStatus()
        }
    }

    var stepIndex: Int {
        currentStep.rawValue + 1
    }

    var totalSteps: Int {
        Step.allCases.count
    }

    var progressTitle: String {
        "Step \(stepIndex) of \(totalSteps)"
    }

    var isHealthKitConnected: Bool {
        healthKitAccessStatus == .available
    }

    var shouldShowSkipHealthKitButton: Bool {
        currentStep == .healthKit && !isHealthKitConnected
    }

    var healthKitButtonTitle: String {
        isHealthKitConnected ? "HealthKit Already Connected" : "Enable HealthKit for Best Experience"
    }

    var readySubtitle: String {
        if isHealthKitConnected {
            return "Create your account and log your first check-in to unlock check-ins and improve insights."
        }

        return "Create your account and log your first check-in to unlock check-ins and improve insights."
    }

    func continueFromOverview() {
        currentStep = .healthKit
    }

    var canGoBack: Bool {
        currentStep != .overview
    }

    func goBack() {
        guard canGoBack else { return }

        switch currentStep {
        case .overview:
            break
        case .healthKit:
            currentStep = .overview
        case .ready:
            currentStep = .healthKit
        }
    }

    func enableHealthKitTapped() {
        guard !isRequestingHealthKitAccess else { return }

        if isHealthKitConnected {
            currentStep = .ready
            return
        }

        Task {
            await requestHealthKitAccess()
        }
    }

    func skipHealthKitTapped() {
        currentStep = .ready
    }

    func finishTapped() {
        SQUserDefaults.shared.markLaunchTutorialCompleted(version: Self.currentVersion)
        SQLogger.shared.log(
            "Launch tutorial completed. HealthKit connected: \(isHealthKitConnected)",
            .info,
            context: .dashboard,
            isPriority: true
        )
        hub.domainEvents.send(.dismissDashboardNavStack)

        Task { @MainActor [onCompletion] in
            await Task.yield()
            await onCompletion(true)
        }
    }

    private func requestHealthKitAccess() async {
        isRequestingHealthKitAccess = true
        defer { isRequestingHealthKitAccess = false }

        do {
            try await healthKitManager.requestAppAuthorization()
            SQLogger.shared.log(
                "Launch tutorial requested HealthKit authorization.",
                .info,
                context: .healthKit
            )
            await refreshHealthKitAccessStatus()
            currentStep = .ready
        } catch {
            SQLogger.shared.log(
                "Launch tutorial HealthKit authorization failed: \(error.localizedDescription)",
                .warning,
                context: .healthKit,
                isPriority: true
            )
            hub.alertEvents.send(.present(.init(error as? SQUserFacingError ?? SQError.standard)))
        }
    }

    private func refreshHealthKitAccessStatus() async {
        healthKitAccessStatus = await healthKitManager.dashboardAccessStatus()
    }
}
