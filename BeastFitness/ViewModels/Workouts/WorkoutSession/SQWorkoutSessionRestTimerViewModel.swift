//
//  SQWorkoutSessionRestTimerViewModel.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 12/16/25.
//

import Foundation
import Observation

import Foundation
import Observation

@Observable
@MainActor
final class SQWorkoutSessionRestTimerViewModel {
    private var timer: Timer?

    enum State: Equatable {
        case idle(duration: TimeInterval)
        case running(endsAt: Date, duration: TimeInterval)
        case paused(remaining: TimeInterval, duration: TimeInterval)
    }
    
    private static let timerDuration: Double = 20

    private(set) var state: State = .idle(duration: timerDuration)

    /// ✅ This is the key: stored observable value that changes every tick
    var remainingTime: TimeInterval = timerDuration

    // MARK: - Derived

    var remainingString: String {
        let total = max(0, Int(remainingTime.rounded(.down)))
        let m = total / 60
        let s = total % 60
        return String(format: "%d:%02d", m, s)
    }

    struct ButtonConfig {
        let text: String
        let action: () -> Void
    }

    var buttonConfig: ButtonConfig {
        switch state {
        case .idle:
            return .init(text: "Start", action: { [weak self] in self?.start() })
        case .running:
            return .init(text: "Skip", action: { [weak self] in self?.reset() })
        case .paused:
            return .init(text: "Resume", action: { [weak self] in self?.resume() })
        }
    }

    // MARK: - Controls
    
    var isPresentedAsActive: Bool {
        switch state {
        case .running, .paused: return true
        case .idle: return false
        }
    }

    func configure(duration: TimeInterval) {
        stopTimer()
        state = .idle(duration: duration)
        remainingTime = duration
    }

    func start() {
        guard case .idle(let duration) = state else { return }
        let endsAt = Date().addingTimeInterval(duration)
        state = .running(endsAt: endsAt, duration: duration)
        remainingTime = duration
        startTicking()
    }

    func pause() {
        guard case .running(let endsAt, let duration) = state else { return }
        stopTimer()
        let remaining = max(0, endsAt.timeIntervalSince(Date()))
        state = .paused(remaining: remaining, duration: duration)
        remainingTime = remaining
    }

    func resume() {
        guard case .paused(let remaining, let duration) = state else { return }
        let endsAt = Date().addingTimeInterval(remaining)
        state = .running(endsAt: endsAt, duration: duration)
        remainingTime = remaining
        startTicking()
    }

    func skip() {
        reset()
    }

    func reset() {
        stopTimer()
        let duration: TimeInterval
        switch state {
        case .idle(let d), .running(_, let d), .paused(_, let d):
            duration = d
        }
        state = .idle(duration: duration)
        remainingTime = duration
    }

    /// Call when app returns to foreground
    func refresh() {
        guard case .running(let endsAt, let duration) = state else { return }
        let r = max(0, endsAt.timeIntervalSince(Date()))
        remainingTime = r
        if r <= 0 {
            reset()
        }
    }

    // MARK: - Private

    private func startTicking() {
        stopTimer()

        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                guard case .running(let endsAt, let duration) = self.state else { return }

                let r = max(0, endsAt.timeIntervalSince(Date()))
                self.remainingTime = r

                if r <= 0 {
                    self.reset()
                }
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}
