//
//  SQLogger.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 9/30/24.
//

import Foundation
import os

enum SQLogContext {
    case general
    case dailyCheckIn
    case deepLink
    case dataProcessing
    case workoutSession
    case workoutSummary
    case workoutList
    case dashboard
}

final class SQLogger {
    static let shared = SQLogger()
    
    enum Level {
        case debug
        case info
        case log
        case error
    }
    
    private func debug(_ message: String, isPriority: Bool) {
        let message = isPriority ? priorityMessage(message) : message
        Logger.general.debug("\(message)")
    }
    
    private func info(_ message: String, isPriority: Bool) {
        let message = isPriority ? priorityMessage(message) : message
        Logger.general.info("\(message)")
    }
    
    private func log(_ message: String, isPriority: Bool) {
        let message = isPriority ? priorityMessage(message) : message
        Logger.general.log("\(message)")
    }
    
    private func error(_ message: String, isPriority: Bool) {
        let message = isPriority ? priorityMessage(message) : message
        Logger.general.error("\(message)")
    }
    
    // TODO: - PTD do something with this screen data
    func log(_ message: String, _ level: Level, context: SQLogContext, isPriority: Bool = false, shouldLog: Bool = true) {
        guard shouldLog else { return }
        switch level {
        case .debug:
            debug(message, isPriority: isPriority)
        case .info:
            info(message, isPriority: isPriority)
        case .log:
            log(message, isPriority: isPriority)
        case .error:
            error(message, isPriority: isPriority)
        }
    }
    
    private func priorityMessage(_ message: String) -> String {
        return "\n\n-------------------\n\n\(message)\n\n-------------------"
    }
    
}

fileprivate extension Logger {
    static let general = Logger(subsystem: "io.github.patpatchpatrick.TheSquad", category: "General")
}
