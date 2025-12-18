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
    private(set) var queue: [SQAlertViewModel] = [] {
        didSet { onVisibilityChanged?(isPresented) }
    }

    var onVisibilityChanged: ((Bool) -> Void)?
    var current: SQAlertViewModel? { queue.first }
    var isPresented: Bool { current != nil }
    
    init(hub: EventHub) {
        self.hub = hub
        handleEventSubscriptions(hub: hub)
    }
    
    private func handleEventSubscriptions(hub: EventHub) {
        
        hub.alertEvents.sink { [weak self] event in
            guard let self else { return }
            
            switch event {
            case .present(let alertViewModel):
                present(alertViewModel)
                
            case .dismiss(let alertViewModel):
                dismiss(alertViewModel)
                
            case .dismissCurrent:
                dismissCurrent()
                
            }
        }.store(in: &cancellables)
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
