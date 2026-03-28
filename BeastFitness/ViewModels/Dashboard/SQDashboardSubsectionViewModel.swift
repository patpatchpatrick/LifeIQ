//
//  SQDashboardSubsectionViewModel.swift
//  BeastFitness
//
//  Created by Claude Code on 2026-02-06.
//

import Foundation
import SwiftUI

@MainActor
@Observable final class SQDashboardSubsectionViewModel: Identifiable {
    struct EmptyStateViewModel {
        let title: String
        let subtitle: String?
        let icon: SQImageSymbol
        let onTap: (() -> Void)?
    }

    /// View model for a title button in the subsection header
    struct TitleButtonViewModel {
        let icon: SQImageSymbol
        let title: String?
        let onTap: () -> Void
    }

    let id: String
    let title: String
    let defaultPriority: Int
    var isCollapsed: Bool
    var dropDownViewModel: SQDropDownMenuViewModel?
    var titleButton: TitleButtonViewModel?
    var columnHeaders: [String]?
    var rowSpacing: CGFloat?
    var maxVisibleRows: Int?
    var emptyState: EmptyStateViewModel?
    var isLocked: Bool = false
    var onLockedTap: (() -> Void)? = nil
    private(set) var isShowingAllRows: Bool = false
    private(set) var rowsByFilter: [String: [SQDashboardRowViewModel]]
    private(set) var activeFilter: String
    private(set) var activeRows: [SQDashboardRowViewModel]

    init(
        id: String,
        title: String,
        defaultPriority: Int = 0,
        rowsByFilter: [String: [SQDashboardRowViewModel]],
        dropDownViewModel: SQDropDownMenuViewModel? = nil,
        titleButton: TitleButtonViewModel? = nil,
        columnHeaders: [String]? = nil,
        rowSpacing: CGFloat? = nil,
        maxVisibleRows: Int? = nil,
        emptyState: EmptyStateViewModel? = nil
    ) {
        self.id = id
        self.title = title
        self.defaultPriority = defaultPriority
        self.rowsByFilter = rowsByFilter
        self.dropDownViewModel = dropDownViewModel
        self.titleButton = titleButton
        self.columnHeaders = columnHeaders
        self.rowSpacing = rowSpacing
        self.maxVisibleRows = maxVisibleRows
        self.emptyState = emptyState
        self.isCollapsed = false

        // Set activeFilter to first key in rowsByFilter or "All"
        let filterKey = dropDownViewModel?.defaultItem.title ?? "All"
        self.activeFilter = filterKey

        // Set activeRows based on activeFilter
        self.activeRows = rowsByFilter[filterKey] ?? []
    }

    func toggleCollapsed() {
        isCollapsed.toggle()
    }

    var visibleRows: [SQDashboardRowViewModel] {
        guard let maxVisibleRows, !isShowingAllRows else { return activeRows }
        return Array(activeRows.prefix(maxVisibleRows))
    }

    var canToggleVisibleRows: Bool {
        guard let maxVisibleRows else { return false }
        return activeRows.count > maxVisibleRows
    }

    var seeMoreTitle: String {
        isShowingAllRows ? "See less" : "See more"
    }

    func toggleShowingAllRows() {
        withAnimation(.easeInOut(duration: 0.2)) {
            isShowingAllRows.toggle()
        }
    }

    func updateActiveFilter(_ filter: String) {
        withAnimation(.easeInOut(duration: 0.2)) {
            activeFilter = filter
            activeRows = rowsByFilter[filter] ?? []
            isShowingAllRows = false
        }
    }

    func cloned() -> SQDashboardSubsectionViewModel {
        let clonedDropDown = Self.cloneDropDown(dropDownViewModel)

        let clonedSection = SQDashboardSubsectionViewModel(
            id: id,
            title: title,
            defaultPriority: defaultPriority,
            rowsByFilter: rowsByFilter,
            dropDownViewModel: clonedDropDown,
            titleButton: titleButton,
            columnHeaders: columnHeaders,
            rowSpacing: rowSpacing,
            maxVisibleRows: maxVisibleRows,
            emptyState: emptyState
        )

        clonedSection.isCollapsed = isCollapsed
        clonedSection.isLocked = isLocked
        clonedSection.onLockedTap = onLockedTap

        if clonedSection.activeFilter != activeFilter {
            clonedSection.updateActiveFilter(activeFilter)
        }

        if isShowingAllRows {
            clonedSection.toggleShowingAllRows()
        }

        if let clonedDropDown {
            clonedDropDown.itemSelectionHandler = { [weak clonedSection] selectedFilter in
                clonedSection?.updateActiveFilter(selectedFilter)
            }
        }

        return clonedSection
    }

    private static func cloneDropDown(_ dropDown: SQDropDownMenuViewModel?) -> SQDropDownMenuViewModel? {
        guard let dropDown else { return nil }

        return SQDropDownMenuViewModel(
            defaultItem: dropDown.defaultItem,
            items: dropDown.items,
            itemSelectionHandler: { _ in }
        )
    }
}
