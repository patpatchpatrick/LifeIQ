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
    private(set) var sections: [SQDashboardSubsectionViewModel]
    private(set) var selectedTimeRange: AppTimeRange
    private(set) var isLoading = false
    let timeRangeMenuViewModel: SQDropDownMenuViewModel?
    private let onTimeRangeSelected: ((AppTimeRange, SQDashboardDetailController) -> Void)?

    init(
        title: String,
        sections: [SQDashboardSubsectionViewModel],
        selectedTimeRange: AppTimeRange,
        showsTimeRangePicker: Bool = false,
        onTimeRangeSelected: ((AppTimeRange, SQDashboardDetailController) -> Void)? = nil
    ) {
        self.title = title
        self.sections = sections
        self.selectedTimeRange = selectedTimeRange
        self.onTimeRangeSelected = onTimeRangeSelected

        if showsTimeRangePicker {
            let items = AppTimeRange.allCases
                .sorted(by: { $0.sortOrder < $1.sortOrder })
                .map { SQDropDownMenuViewModel.Item(title: $0.rawValue) }

            self.timeRangeMenuViewModel = SQDropDownMenuViewModel(
                defaultItem: .init(title: selectedTimeRange.rawValue),
                items: items,
                itemSelectionHandler: { _ in }
            )
        } else {
            self.timeRangeMenuViewModel = nil
        }

        self.timeRangeMenuViewModel?.itemSelectionHandler = { [weak self] selectedTitle in
            guard let self,
                  let selectedRange = AppTimeRange.allCases.first(where: { $0.rawValue == selectedTitle }),
                  selectedRange != self.selectedTimeRange else { return }

            self.selectedTimeRange = selectedRange
            self.isLoading = true
            self.onTimeRangeSelected?(selectedRange, self)
        }
    }

    func updateSections(_ sections: [SQDashboardSubsectionViewModel], selectedTimeRange: AppTimeRange) {
        self.sections = sections
        self.selectedTimeRange = selectedTimeRange
        let selectedItem = SQDropDownMenuViewModel.Item(title: selectedTimeRange.rawValue)
        timeRangeMenuViewModel?.updateItems(
            AppTimeRange.allCases
                .sorted(by: { $0.sortOrder < $1.sortOrder })
                .map { SQDropDownMenuViewModel.Item(title: $0.rawValue) },
            defaultItem: selectedItem
        )
    }

    func setLoading(_ isLoading: Bool) {
        self.isLoading = isLoading
    }
}
