//
//  SQSettingsRowViewModel.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 12/17/25.
//

import Foundation
import Observation

@MainActor
struct SQSettingsSectionViewModel: Identifiable {
    let id = UUID()
    let title: String
    let rows: [SQSettingsRowViewModel]
}

@MainActor
@Observable
final class SQSettingsRowViewModel: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String?
    let icon: SQImageSymbol
    let showsChevron: Bool
    let action: @MainActor () -> Void

    init(
        title: String,
        subtitle: String? = nil,
        icon: SQImageSymbol,
        showsChevron: Bool = false,
        action: @escaping @MainActor () -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.showsChevron = showsChevron
        self.action = action
    }
}
