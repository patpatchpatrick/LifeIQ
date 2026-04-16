//
//  SQWatchInterface.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 12/18/25.
//

import BeastFitnessCore
import Foundation

@MainActor
protocol SQWatchInterfacing {
    func startStrengthWorkoutOnWatch()
    func sendActiveWorkoutPayloadToWatch(_ workout: SQActiveWorkoutSessionPayload) throws
}

@MainActor
final class SQWatchInterface: NSObject, SQWatchInterfacing {
    static let shared = SQWatchInterface()

    private override init() {
        super.init()
    }

    // The watch app is currently unlinked from the iOS app target.
    // Keep the interface as a no-op so workout flows continue to compile cleanly.
    func configureMirroringHandler() {
        SQLogger.shared.log(
            "Watch mirroring is disabled in the iOS app target.",
            .debug,
            context: .watchInterface
        )
    }

    func startStrengthWorkoutOnWatch() {
        SQLogger.shared.log(
            "Ignoring watch workout start because watch integration is disabled.",
            .debug,
            context: .watchInterface
        )
    }

    func sendActiveWorkoutPayloadToWatch(_ workout: SQActiveWorkoutSessionPayload) throws {
        SQLogger.shared.log(
            "Ignoring watch payload because watch integration is disabled.",
            .debug,
            context: .watchInterface
        )
    }
}
