//
//  SQMetricsListState.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 1/2/26.
//


import SwiftUI

@MainActor
protocol SQMetricsListStating: AnyObject {
}

@MainActor
@Observable final class SQMetricsListState: SQMetricsListStating {
    
    private let hub: EventHub
    
    init(hub: EventHub) {
        self.hub = hub
    }
}
