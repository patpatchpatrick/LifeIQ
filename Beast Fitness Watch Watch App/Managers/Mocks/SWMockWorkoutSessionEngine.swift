//
//  SWMockWorkoutSessionEngine.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 12/19/25.
//

import Foundation
import HealthKit

public final class SWMockWorkoutSessionEngine: SQWorkoutSessionEngine {
    private var timer: DispatchSourceTimer?
    private var onEvent: (@Sendable (SQWorkoutEngineEvent) -> Void)?

    private var bpm: Double = 92
    private var kcal: Double = 0

    public init() {}

    public func start(
        config: HKWorkoutConfiguration,
        onEvent: @escaping @Sendable (SQWorkoutEngineEvent) -> Void
    ) {
        self.onEvent = onEvent

        let start = Date()
        onEvent(.didStart(start: start))
        onEvent(.didChangeState(from: .notStarted, to: .running, date: start))

        let t = DispatchSource.makeTimerSource(queue: .global(qos: .utility))
        t.schedule(deadline: .now(), repeating: .seconds(1))
        t.setEventHandler { [weak self] in
            guard let self else { return }
            let now = Date()

            // Random-walk HR
            self.bpm += Double.random(in: -3...4)
            self.bpm = min(max(self.bpm, 55), 175)

            // Simple energy burn model
            self.kcal += Double.random(in: 0.8...2.2)

            onEvent(.heartRate(bpm: self.bpm, date: now))
            onEvent(.activeEnergy(kcal: self.kcal, date: now))
        }

        self.timer = t
        t.resume()
    }

    public func stop() {
        timer?.cancel()
        timer = nil

        let end = Date()
        onEvent?(.didChangeState(from: .running, to: .ended, date: end))
        onEvent?(.didStop(end: end))
    }
}
