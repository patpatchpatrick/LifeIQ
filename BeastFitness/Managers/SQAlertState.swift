//
//  SQAlertManager.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 12/17/25.
//

import Foundation
import Observation
import Combine

@MainActor
@Observable
final class SQAlertState {
    private let hub: EventHub
    private var cancellables = Set<AnyCancellable>()
    private(set) var queue: [SQAlertViewModel] = []
    // Track which host is topmost
    private var hostStack: [UUID] = []

    var current: SQAlertViewModel? { queue.first }
    var isPresented: Bool { current != nil }
    
    init(hub: EventHub) {
        self.hub = hub
        print("PTD Setup Alert")
        handleEventSubscriptions(hub: hub)
    }
    
    private func handleEventSubscriptions(hub: EventHub) {
        
        hub.alertEvents.sink { [weak self] event in
            guard let self else { return }
            
            switch event {
            case .present(let alertViewModel):
                print("PTD Received ALERT2")
                present(alertViewModel)
                
            case .dismiss(let alertViewModel):
                dismiss(alertViewModel)
                
            case .dismissCurrent:
                dismissCurrent()
                
            }
        }.store(in: &cancellables)
    }
    
    // MARK: Host registration - ensures that only the top level View will display alerts

    func pushHost(_ id: UUID) {
        hostStack.append(id)
    }

    func popHost(_ id: UUID) {
        // remove last occurrence (safe if out-of-order)
        if let idx = hostStack.lastIndex(of: id) {
            hostStack.remove(at: idx)
        }
    }

    func isTopHost(_ id: UUID) -> Bool {
        hostStack.last == id
    }
    
    // MARK: - Alert Actions

    func present(_ alert: SQAlertViewModel) {
        queue.append(alert)
    }
    
    func dismiss(_ alert: SQAlertViewModel) {
        guard let index = queue.lastIndex(where: { $0.id == alert.id }) else {
            return
        }
        queue.remove(at: index)
    }

    func dismissCurrent() {
        guard !queue.isEmpty else { return }
        queue.removeFirst()
    }

    func dismissAll() {
        queue.removeAll()
    }
}
