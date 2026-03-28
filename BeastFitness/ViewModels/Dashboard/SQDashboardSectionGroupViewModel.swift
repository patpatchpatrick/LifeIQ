//
//  SQDashboardSectionGroupViewModel.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 2/6/26.
//

import Foundation

@Observable @MainActor
final class SQDashboardSectionGroupViewModel: Identifiable {
    let id: String
    let title: String
    let defaultPriority: Int
    var isExpanded: Bool = true
    var sections: [SQDashboardSubsectionViewModel]

    init(
        id: String,
        title: String,
        defaultPriority: Int = 0,
        sections: [SQDashboardSubsectionViewModel]
    ) {
        self.id = id
        self.title = title
        self.defaultPriority = defaultPriority
        self.sections = sections
    }

    func toggleExpanded() {
        isExpanded.toggle()
    }

    func cloned() -> SQDashboardSectionGroupViewModel {
        let clonedGroup = SQDashboardSectionGroupViewModel(
            id: id,
            title: title,
            defaultPriority: defaultPriority,
            sections: sections.map { $0.cloned() }
        )
        clonedGroup.isExpanded = isExpanded
        return clonedGroup
    }
}
