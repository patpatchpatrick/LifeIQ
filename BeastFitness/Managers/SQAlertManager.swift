//
//  SQAlertManager.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 12/17/25.
//

import Foundation
import Observation

@MainActor
@Observable
final class SQAlertState {
    private(set) var queue: [SQAlertViewModel] = []

    var current: SQAlertViewModel? { queue.first }
    var isPresented: Bool { current != nil }

    func present(_ alert: SQAlertViewModel) {
        queue.append(alert)
    }

    func dismissCurrent() {
        guard !queue.isEmpty else { return }
        queue.removeFirst()
    }

    func dismissAll() {
        queue.removeAll()
    }
}
