//
//  SQDashboardSubsectionViewModel.swift
//  BeastFitness
//
//  Created by Claude Code on 2026-02-06.
//

import Foundation

@MainActor
@Observable final class SQDashboardSubsectionViewModel: Identifiable {
    let id: String
    let title: String
    var isCollapsed: Bool
    var dropDownViewModel: SQDropDownMenuViewModel?
    private(set) var rowsByFilter: [String: [Any]]
    private(set) var activeFilter: String
    private(set) var activeRows: [Any]

    init(
        id: String,
        title: String,
        rowsByFilter: [String: [Any]],
        dropDownViewModel: SQDropDownMenuViewModel? = nil
    ) {
        self.id = id
        self.title = title
        self.rowsByFilter = rowsByFilter
        self.dropDownViewModel = dropDownViewModel
        self.isCollapsed = false

        // Set activeFilter to first key in rowsByFilter or "All"
        let filterKey = rowsByFilter.keys.first ?? "All"
        self.activeFilter = filterKey

        // Set activeRows based on activeFilter
        self.activeRows = rowsByFilter[filterKey] ?? []
    }

    func toggleCollapsed() {
        isCollapsed.toggle()
    }

    func updateActiveFilter(_ filter: String) {
        activeFilter = filter
        activeRows = rowsByFilter[filter] ?? []
    }
}
