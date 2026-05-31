//
//  SQDashboardDetailController.swift
//  BeastFitness
//
//  Created by Codex on 5/30/26.
//

import Foundation

@MainActor
@Observable
final class SQDashboardDetailController: Identifiable {
    let id = UUID().uuidString
    let title: String
    let sections: [SQDashboardSubsectionViewModel]

    init(title: String, sections: [SQDashboardSubsectionViewModel]) {
        self.title = title
        self.sections = sections
    }
}
