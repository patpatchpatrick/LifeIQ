//
//  SQToastManager.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 12/17/25.
//


import Foundation
import Observation
import Combine

@MainActor
@Observable
final class SQToastState {
    private let hub: EventHub
    private var cancellables = Set<AnyCancellable>()
    private(set) var queue: [SQToastViewModel] = [] {
        didSet {
            onVisibilityChanged?(isPresented)
        }
    }

    var onVisibilityChanged: ((Bool) -> Void)?
    var current: SQToastViewModel? { queue.first }
    var isPresented: Bool { current != nil }
    
    init(hub: EventHub) {
        self.hub = hub
        handleEventSubscriptions(hub: hub)
    }
    
    private func handleEventSubscriptions(hub: EventHub) {
        
        hub.toastEvents.sink { [weak self] event in
            guard let self else { return }
            
            switch event {
            case .present(let toast):
                self.show(toast)
            }
        }.store(in: &cancellables)
    }

    func show(_ toast: SQToastViewModel) {
        queue.append(toast)
    }

    func dismissCurrent() {
        guard !queue.isEmpty else { return }
        queue.removeFirst()
    }

    func dismiss(_ toast: SQToastViewModel) {
        guard let idx = queue.lastIndex(where: { $0.id == toast.id }) else { return }
        queue.remove(at: idx)
    }

    func dismissAll() {
        queue.removeAll()
    }
}
