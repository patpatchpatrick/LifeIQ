//
//  SWRootState.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 12/19/25.
//

import SwiftUI
import Combine

@MainActor
protocol SWRootStating: AnyObject {
    var title: String { get }
    var heartRateTitle: String { get }
    func updateTitle(to title: String)
}

@MainActor
@Observable final class SWRootState: SWRootStating {
    private(set) var title: String
    private(set) var heartRateTitle: String
    
    let hub: SWEventHub
    
    init(hub: SWEventHub) {
        self.hub = hub
        self.title = "Beast Fitness"
        self.heartRateTitle = "Heart Rate: No Data"
    }
    
    func updateTitle(to title: String) {
        self.title = title
    }
    
    func updateHeartRate(to title: String) {
        heartRateTitle = title
    }
}
