//
//  SWAppState.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 12/19/25.
//


import SwiftUI
import Combine

@MainActor
@Observable
final class SWAppState {
    static let shared = SWAppState()
    
    let useMockData: Bool = false
    
    let hub = SWEventHub()
    
    let rootState: SWRootState

    init() {
        self.rootState = .init(hub: hub)
    }
}
