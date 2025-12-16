//
//  SQWorkoutSessionTimerViewModel.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 12/16/25.
//

import Foundation
import Observation

@Observable
@MainActor
final class SQWorkoutSessionTimerViewModel {
    private var timer: Timer?

    // MARK: - State

    enum State: Equatable {
        case idle
        case running(workoutStart: Date, segmentStart: Date, accumulated: TimeInterval)
        case paused(workoutStart: Date, accumulated: TimeInterval)
    }

    private(set) var state: State = .idle

    // MARK: - Derived / UI

    var workoutStartDate: Date? {
        switch state {
        case .idle: return nil
        case .running(let workoutStart, _, _): return workoutStart
        case .paused(let workoutStart, _): return workoutStart
        }
    }

    var isRunning: Bool {
        if case .running = state { return true }
        return false
    }

    var hasStarted: Bool {
        state != .idle
    }

    /// “Truth” of elapsed time, computed from state + wall clock.
    /// This is what should be used when building your workout model.
    func currentActiveDuration(at now: Date = Date()) -> TimeInterval {
        switch state {
        case .idle:
            return 0
        case .paused(_, let accumulated):
            return accumulated
        case .running(_, let segmentStart, let accumulated):
            return accumulated + now.timeIntervalSince(segmentStart)
        }
    }

    /// Published for UI updates (ticks)
    var elapsedTime: TimeInterval = 0

    var elapsedTimeString: String {
        let total = max(0, Int(elapsedTime))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, s)
            : String(format: "%d:%02d", m, s)
    }

    var visibleTimeString: String {
        elapsedTimeString
    }

    struct TimerButtonConfig {
        let icon: SQImageSymbol?
        let text: String?
        let action: () -> Void
        
        init(icon: SQImageSymbol? = nil, text: String? = nil, action: @escaping () -> Void) {
            self.icon = icon
            self.text = text
            self.action = action
        }
    }

    var workoutTimerButtonConfig: TimerButtonConfig {
        switch state {
        case .idle:
            return .init(icon: .play, action: { [weak self] in self?.start() })
        case .running:
            return .init(icon: .pause, action: { [weak self] in self?.pause() })
        case .paused:
            return .init(icon: .play, action: { [weak self] in self?.resume() })
        }
    }
    
    var restTimerButtonConfig: TimerButtonConfig {
        switch state {
        case .idle:
            return .init(text: "Start", action: { [weak self] in self?.start() })
        case .running:
            return .init(text: "Skip", action: { [weak self] in self?.stop() })
        case .paused:
            return .init(text: "Resume", action: { [weak self] in self?.resume() })
        }
    }

    // MARK: - Controls

    func start() {
        guard case .idle = state else { return }

        let now = Date()
        state = .running(workoutStart: now, segmentStart: now, accumulated: 0)
        syncElapsedAndStartTimer()
    }

    func resume() {
        guard case .paused(let workoutStart, let accumulated) = state else { return }

        let now = Date()
        state = .running(workoutStart: workoutStart, segmentStart: now, accumulated: accumulated)
        syncElapsedAndStartTimer()
    }

    func pause() {
        guard case .running(let workoutStart, let segmentStart, let accumulated) = state else { return }

        let now = Date()
        let newAccumulated = accumulated + now.timeIntervalSince(segmentStart)
        state = .paused(workoutStart: workoutStart, accumulated: newAccumulated)

        // Freeze + stop ticking
        elapsedTime = newAccumulated
        stopTimer()
    }

    func stop() {
        state = .idle
        elapsedTime = 0
        stopTimer()
    }

    /// Call when app returns to foreground to instantly refresh the title.
    func refreshElapsed() {
        guard hasStarted else { return }
        elapsedTime = currentActiveDuration()
    }

    // MARK: - Timer tick

    private func syncElapsedAndStartTimer() {
        // Update immediately so UI doesn’t wait for next tick
        elapsedTime = currentActiveDuration()

        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                // Only tick while running
                guard case .running = self.state else { return }
                self.elapsedTime = self.currentActiveDuration()
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}
