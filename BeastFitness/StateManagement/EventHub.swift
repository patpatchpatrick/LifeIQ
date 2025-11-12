//
//  EventHub.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 11/11/25.
//

import Combine

enum DomainEvent {
    /// Navigation
    case changeTab(NavigationState.Tab)
}

@MainActor
final class EventHub {
    let events = PassthroughSubject<DomainEvent, Never>()
}
