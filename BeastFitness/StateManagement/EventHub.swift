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

enum WorkoutEvent {
    case workoutUpdated(SQWorkoutSessionable)
}

@MainActor
final class EventHub {
    let domainEvents = PassthroughSubject<DomainEvent, Never>()
    let workoutEvents = PassthroughSubject<WorkoutEvent, Never>()
}
