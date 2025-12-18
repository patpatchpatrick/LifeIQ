//
//  SQToastViewModel.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 12/17/25.
//

import Foundation

struct SQToastViewModel: Identifiable, Equatable {
    enum Style: Equatable {
        case normal
        case success
        case warning
        case error
    }

    let id: UUID
    let title: String
    let subtitle: String?
    let style: Style
    let duration: TimeInterval  // auto-dismiss
    let isUserDismissable: Bool

    init(
        id: UUID = UUID(),
        title: String,
        subtitle: String? = nil,
        style: Style = .normal,
        duration: TimeInterval = 2.0,
        isUserDismissable: Bool = true
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.style = style
        self.duration = duration
        self.isUserDismissable = isUserDismissable
    }
}
