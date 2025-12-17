//
//  SQAlertViewModel.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 12/17/25.
//

import Foundation

struct SQAlertViewModel: Identifiable, Equatable {
    struct Action {
        let title: String
        let role: Role?
        let shouldDismissOnTap: Bool
        let handler: (@MainActor () -> Void)?

        enum Role: Equatable {
            case normal
            case destructive
            case cancel
        }

        init(
            title: String,
            role: Role? = nil,
            shouldDismissOnTap: Bool = true,
            handler: (@MainActor () -> Void)? = nil
        ) {
            self.title = title
            self.role = role
            self.shouldDismissOnTap = shouldDismissOnTap
            self.handler = handler
        }
    }

    let id: UUID
    let title: String
    let subtitle: String?
    let primary: Action
    let secondary: Action?

    init(
        id: UUID = UUID(),
        title: String,
        subtitle: String? = nil,
        primary: Action,
        secondary: Action? = nil
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.primary = primary
        self.secondary = secondary
    }
    
    init(_ sqError: SQUserFacingError) {
        self.init(title: sqError.userFacingTitle, subtitle: sqError.userFacingDescription, primary: .init(title: "Got it", role: .cancel))
    }

    static func == (lhs: SQAlertViewModel, rhs: SQAlertViewModel) -> Bool {
        // Avoid comparing handlers
        lhs.id == rhs.id &&
        lhs.title == rhs.title &&
        lhs.subtitle == rhs.subtitle &&
        lhs.primary.title == rhs.primary.title &&
        lhs.primary.role == rhs.primary.role &&
        lhs.secondary?.title == rhs.secondary?.title &&
        lhs.secondary?.role == rhs.secondary?.role
    }
}
