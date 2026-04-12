//
//  Untitled.swift
//  BeastFitnessCore
//
//  Created by Patrick Doyle on 12/19/25.
//

import Foundation
import os

// MARK: - Platform contexts

#if os(iOS)
public enum SQiOSLogContext: Sendable {
    case general
    case analytics
    case dailyCheckIn
    case loginSignup
    case metricsManager
    case deepLink
    case dataProcessing
    case workoutSession
    case workoutSummary
    case workoutManager
    case workoutList
    case watchInterface
    case dashboard
    case healthKit
    case network
}
#endif

#if os(watchOS)
public enum SQWatchLogContext: Sendable {
    case general
    case watchInterface
    case healthKit
    case workoutSession
}
#endif

// MARK: - Logger

/// Non-async, thread-safe logger usable from iOS + watch targets and from a Swift Package.
public final class SQLogger: @unchecked Sendable {

    public static let shared = SQLogger()

    public enum Level: Sendable {
        case debug
        case info
        case log
        case warning
        case error
    }

    private let queue = DispatchQueue(
        label: "io.github.patpatchpatrick.BeastFitness.SQLogger",
        qos: .utility
    )

    public init() {}

    // MARK: - iOS-only API

    #if os(iOS)
    public func log(
        _ message: String,
        _ level: Level,
        context: SQiOSLogContext,
        isPriority: Bool = false,
        shouldLog: Bool = true
    ) {
        guard shouldLog else { return }

        let finalMessage = isPriority ? priorityMessage(message) : message
        let logger = Logger.logger(for: context)

        queue.async { logger.write(finalMessage, level: level) }
    }
    #endif

    // MARK: - watchOS-only API

    #if os(watchOS)
    public func logW(
        _ message: String,
        _ level: Level,
        context: SQWatchLogContext,
        isPriority: Bool = false,
        shouldLog: Bool = true
    ) {
        guard shouldLog else { return }

        let finalMessage = isPriority ? priorityMessage(message) : message
        let logger = Logger.logger(for: context)

        queue.async { logger.write(finalMessage, level: level) }
    }
    #endif

    // MARK: - Private helpers

    private func priorityMessage(_ message: String) -> String {
        "\n\n-------------------\n\n\(message)\n\n-------------------"
    }
}

// MARK: - Logger helpers

fileprivate extension Logger {

    func write(_ message: String, level: SQLogger.Level) {
        switch level {
        case .debug:
            debug("\(message)")
        case .info:
            info("\(message)")
        case .log:
            log("\(message)")
        case .warning:
            warning("\(message)")
        case .error:
            error("\(message)")
        }
    }
}

// MARK: - OSLog categories per platform

#if os(iOS)
fileprivate extension Logger {

    static func logger(for context: SQiOSLogContext) -> Logger {
        switch context {
        case .general:         return .general
        case .analytics:       return .analytics
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
        case .metricsManager:  return .metricsManager
        case .network:         return .network
        case .loginSignup:     return .loginSignuo
        }
    }

    static let subsystem = "io.github.patpatchpatrick.BeastFitness"

    static let general        = Logger(subsystem: subsystem, category: "General")
    static let analytics      = Logger(subsystem: subsystem, category: "Analytics")
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
    static let metricsManager = Logger(subsystem: subsystem, category: "MetricsManager")
    static let network        = Logger(subsystem: subsystem, category: "Network")
    static let loginSignuo    = Logger(subsystem: subsystem, category: "LoginSignup")
}
#endif

#if os(watchOS)
fileprivate extension Logger {

    static func logger(for context: SQWatchLogContext) -> Logger {
        switch context {
        case .general:        return .general
        case .watchInterface: return .watchInterface
        case .healthKit:      return .healthKit
        case .workoutSession: return .workoutSession
        }
    }

    static let subsystem = "io.github.patpatchpatrick.BeastFitness"

    static let general        = Logger(subsystem: subsystem, category: "General")
    static let watchInterface = Logger(subsystem: subsystem, category: "WatchInterface")
    static let healthKit      = Logger(subsystem: subsystem, category: "HealthKit")
    static let workoutSession = Logger(subsystem: subsystem, category: "WorkoutSession")
}
#endif
