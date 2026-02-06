//
//  SQModalState.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 2/2/26.
//

import Foundation
import Observation
import Combine

@MainActor
@Observable
final class SQModalState {
    private let hub: EventHub
    private var cancellables = Set<AnyCancellable>()

    enum ModalContent {
        case datePicker(
            dateEntries: [SQDatePickerModal.DateEntry],
            onDateSelected: (Date) -> Void
        )
    }

    private(set) var currentModal: ModalContent? {
        didSet { onVisibilityChanged?(isPresented) }
    }
    var onVisibilityChanged: ((Bool) -> Void)?
    var isPresented: Bool { currentModal != nil }

    init(hub: EventHub) {
        self.hub = hub
        handleEventSubscriptions(hub: hub)
    }

    private func handleEventSubscriptions(hub: EventHub) {
        hub.modalEvents.sink { [weak self] event in
            guard let self else { return }

            switch event {
            case .presentDatePicker(let dateEntries, let onDateSelected):
                currentModal = .datePicker(
                    dateEntries: dateEntries,
                    onDateSelected: onDateSelected
                )

            case .dismiss:
                currentModal = nil
            }
        }.store(in: &cancellables)
    }

    func dismiss() {
        currentModal = nil
    }
}
