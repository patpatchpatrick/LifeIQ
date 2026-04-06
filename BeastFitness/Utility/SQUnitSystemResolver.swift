//
//  SQUnitSystemResolver.swift
//  BeastFitness
//

import Foundation

enum SQUnitSystemResolver {
    static func resolve(for user: SQUser?) -> SQUnitSystem {
        user?.unitSystem
        ?? SQUserDefaults.shared.preferredUnitSystem
        ?? .defaultForCurrentLocale
    }
}
