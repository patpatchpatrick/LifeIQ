//
//  Untitled.swift
//  BeastFitnessCore
//
//  Created by Patrick Doyle on 12/19/25.
//

import Foundation
import os

public enum SQLogContext {
    case general
    case dailyCheckIn
    case deepLink
    case dataProcessing
    case workoutSession
    case workoutSummary
    case workoutManager
    case workoutList
    case dashboard
    case healthKit
    case watchInterface
}

/// Non-async, thread-safe logger usable from iOS + watch targets and from a Swift Package.
public final class SQLogger: @unchecked Sendable {

    public static let shared = SQLogger()

    public enum Level {
        case debug
        case info
        case log
        case error
    }

    // Serial queue guarantees ordering + thread-safety without requiring `await`.
    private let queue = DispatchQueue(label: "io.github.patpatchpatrick.BeastFitness.SQLogger", qos: .utility)

    public init() {}

    // MARK: - Public API

    public func log(
        _ message: String,
        _ level: Level,
        context: SQLogContext,
        isPriority: Bool = false,
        shouldLog: Bool = true
    ) {
        guard shouldLog else { return }

        let finalMessage = isPriority ? priorityMessage(message) : message
        let logger = Logger.logger(for: context)

        // Make logging thread-safe + ordered, but caller doesn't need `await`.
        queue.async {
            switch level {
            case .debug:
                logger.debug("\(finalMessage)")
            case .info:
                logger.info("\(finalMessage)")
            case .log:
                logger.log("\(finalMessage)")
            case .error:
                logger.error("\(finalMessage)")
            }
        }
    }

    // MARK: - Private helpers

    private func priorityMessage(_ message: String) -> String {
        "\n\n-------------------\n\n\(message)\n\n-------------------"
    }
}

// MARK: - OSLog categories per context (no mutable state)

fileprivate extension Logger {

    static func logger(for context: SQLogContext) -> Logger {
        switch context {
        case .general:         return .general
        case .dailyCheckIn:    return .dailyCheckIn
        case .deepLink:        return .deepLink
        case .dataProcessing:  return .dataProcessing
        case .workoutSession:  return .workoutSession
        case .workoutSummary:  return .workoutSummary
        case .workoutManager:  return .workoutManager
        case .workoutList:     return .workoutList
        case .dashboard:       return .dashboard
        case .healthKit:       return .healthKit
        case .watchInterface:  return .watchInterface
        }
    }

    static let subsystem = "io.github.patpatchpatrick.TheSquad"

    static let general        = Logger(subsystem: subsystem, category: "General")
    static let dailyCheckIn   = Logger(subsystem: subsystem, category: "DailyCheckIn")
    static let deepLink       = Logger(subsystem: subsystem, category: "DeepLink")
    static let dataProcessing = Logger(subsystem: subsystem, category: "DataProcessing")
    static let workoutSession = Logger(subsystem: subsystem, category: "WorkoutSession")
    static let workoutSummary = Logger(subsystem: subsystem, category: "WorkoutSummary")
    static let workoutManager = Logger(subsystem: subsystem, category: "WorkoutManager")
    static let workoutList    = Logger(subsystem: subsystem, category: "WorkoutList")
    static let dashboard      = Logger(subsystem: subsystem, category: "Dashboard")
    static let healthKit      = Logger(subsystem: subsystem, category: "HealthKit")
    static let watchInterface = Logger(subsystem: subsystem, category: "WatchInterface")
}
