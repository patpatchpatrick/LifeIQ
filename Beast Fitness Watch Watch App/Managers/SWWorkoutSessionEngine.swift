//
//  SWWorkoutSessionEngine.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 12/19/25.
//

import Foundation
import HealthKit

import Foundation
import HealthKit

public protocol SQWorkoutSessionEngine: Sendable {
    func start(
        config: HKWorkoutConfiguration,
        onEvent: @escaping @Sendable (SQWorkoutEngineEvent) -> Void
    )
    func stop()
}

public final class HKWorkoutSessionEngine: NSObject, SQWorkoutSessionEngine {
    private let healthStore: HKHealthStore

    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?
    private var onEvent: (@Sendable (SQWorkoutEngineEvent) -> Void)?

    public init(healthStore: HKHealthStore = HKHealthStore()) {
        self.healthStore = healthStore
        super.init()
    }

    public func start(
        config: HKWorkoutConfiguration,
        onEvent: @escaping @Sendable (SQWorkoutEngineEvent) -> Void
    ) {
        self.onEvent = onEvent

        Task {
            do {
                try await ensureAuthorization()

                let session = try HKWorkoutSession(healthStore: healthStore, configuration: config)
                let builder = session.associatedWorkoutBuilder()

                session.delegate = self
                builder.delegate = self
                builder.dataSource = HKLiveWorkoutDataSource(
                    healthStore: healthStore,
                    workoutConfiguration: config
                )

                self.session = session
                self.builder = builder

                let start = Date()
                onEvent(.didStart(start: start))
                session.startActivity(with: start)

                builder.beginCollection(withStart: start) { [weak self] success, error in
                    if let error {
                        self?.onEvent?(.didFail(errorDescription: "beginCollection: \(error.localizedDescription)"))
                    } else if !success {
                        self?.onEvent?(.didFail(errorDescription: "beginCollection returned success=false"))
                    }
                }

                session.startMirroringToCompanionDevice { [weak self] success, error in
                    if let error {
                        self?.onEvent?(.didFail(errorDescription: "startMirroring: \(error.localizedDescription)"))
                    } else if !success {
                        self?.onEvent?(.didFail(errorDescription: "startMirroring returned success=false"))
                    }
                }

            } catch {
                onEvent(.didFail(errorDescription: error.localizedDescription))
            }
        }
    }

    public func stop() {
        let end = Date()
        session?.end()
        builder?.endCollection(withEnd: end) { [weak self] _, _ in
            self?.builder?.finishWorkout { _, _ in }
        }
        onEvent?(.didStop(end: end))
    }

    private func ensureAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else { return }

        let hr = HKQuantityType.quantityType(forIdentifier: .heartRate)!
        let activeEnergy = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
        let workoutType = HKObjectType.workoutType()

        try await healthStore.requestAuthorization(
            toShare: [workoutType],
            read: [hr, activeEnergy]
        )
    }
}

// MARK: - Delegates

extension HKWorkoutSessionEngine: HKWorkoutSessionDelegate {
    public nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didChangeTo toState: HKWorkoutSessionState,
        from fromState: HKWorkoutSessionState,
        date: Date
    ) {
        onEvent?(.didChangeState(from: fromState, to: toState, date: date))
    }

    public nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didFailWithError error: Error
    ) {
        onEvent?(.didFail(errorDescription: error.localizedDescription))
    }
}

extension HKWorkoutSessionEngine: HKLiveWorkoutBuilderDelegate {
    public nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}

    public nonisolated func workoutBuilder(
        _ workoutBuilder: HKLiveWorkoutBuilder,
        didCollectDataOf collectedTypes: Set<HKSampleType>
    ) {
        let now = Date()

        if let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate),
           collectedTypes.contains(hrType),
           let stats = workoutBuilder.statistics(for: hrType),
           let q = stats.mostRecentQuantity() {

            let bpm = q.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
            onEvent?(.heartRate(bpm: bpm, date: now))
        }

        if let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned),
           collectedTypes.contains(energyType),
           let stats = workoutBuilder.statistics(for: energyType),
           let q = stats.sumQuantity() {

            let kcal = q.doubleValue(for: .kilocalorie())
            onEvent?(.activeEnergy(kcal: kcal, date: now))
        }
    }
}
