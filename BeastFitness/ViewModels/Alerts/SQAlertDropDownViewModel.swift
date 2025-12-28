//
//  SQAlertDropDownViewModel.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 12/28/25.
//

import SwiftUI

@Observable
@MainActor
final class SQAlertDropDownViewModel: Identifiable {
    struct Option: Identifiable, Equatable {
        let id: String
        let title: String
    }

    let id = UUID()
    let title: String?
    let options: [Option]

    /// ✅ This is the state you want to read later
    var selectedOptionId: String

    init(
        title: String? = nil,
        options: [Option],
        defaultSelectedOptionId: String? = nil
    ) {
        self.title = title
        self.options = options
        self.selectedOptionId = defaultSelectedOptionId ?? options.first?.id ?? ""
    }

    var selectedOption: Option? {
        options.first { $0.id == selectedOptionId }
    }
}
