//
//  SettingsState.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 12/17/25.
//


import SwiftUI
import Combine

@MainActor
protocol SettingsStating: AnyObject {
    var hub: EventHub { get }
}

@MainActor
@Observable final class SettingsState: SettingsStating {
    let hub: EventHub
    
    init(hub: EventHub) {
        self.hub = hub
    }
}
