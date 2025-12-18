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
    case displaySettings
}

enum WorkoutEvent {
    case workoutsUpdated([String: SQWorkoutSessionable]) /// [Workout ID : Workout]
    case workoutsDeleted([String: SQWorkoutSessionable]) /// [Workout ID : Workout]
}

enum AlertEvent {
    case present(_ alert: SQAlertViewModel)
    case dismiss(_ alert: SQAlertViewModel)
    case dismissCurrent
}

enum ToastEvent {
    case present(_ toast: SQToastViewModel)
}

@MainActor
final class EventHub {
    let domainEvents = PassthroughSubject<DomainEvent, Never>()
    let workoutEvents = PassthroughSubject<WorkoutEvent, Never>()
    let alertEvents = PassthroughSubject<AlertEvent, Never>()
    let toastEvents = PassthroughSubject<ToastEvent, Never>()
}
