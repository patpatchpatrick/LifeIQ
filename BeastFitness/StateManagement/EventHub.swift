//
//  EventHub.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 11/11/25.
//

import Combine
import Foundation

enum DomainEvent {
    /// Navigation
    case pushDashboardRoute(SQNavRoute.DashboardRoute)
    case popDashboardRoute
    
    case changeTab(NavigationState.Tab)
    
    case displaySettings
}

enum WorkoutEvent {
    case workoutsUpdated([String: SQWorkoutSessionable]) /// [Workout ID : Workout]
    case workoutsDeleted([String: SQWorkoutSessionable]) /// [Workout ID : Workout]
    case activeWorkoutUpdate(SQActiveWorkoutSessionPayload)
}

enum MetricEvent {
    case metricsUpdated
}

enum AlertEvent {
    case present(_ alert: SQAlertViewModel)
    case dismiss(_ alert: SQAlertViewModel)
    case dismissCurrent
}

enum ToastEvent {
    case present(_ toast: SQToastViewModel)
}

enum ModalEvent {
    case presentDatePicker(
        dateEntries: [SQDatePickerModal.DateEntry],
        selectedDate: Date?,
        selectedPeriod: SQMetricPeriod?,
        onDateSelected: (Date, SQMetricPeriod) -> Void
    )
    case dismiss
}

@MainActor
final class EventHub {
    let domainEvents = PassthroughSubject<DomainEvent, Never>()
    let workoutEvents = PassthroughSubject<WorkoutEvent, Never>()
    let metricEvents = PassthroughSubject<MetricEvent, Never>()
    let alertEvents = PassthroughSubject<AlertEvent, Never>()
    let toastEvents = PassthroughSubject<ToastEvent, Never>()
    let modalEvents = PassthroughSubject<ModalEvent, Never>()
}
