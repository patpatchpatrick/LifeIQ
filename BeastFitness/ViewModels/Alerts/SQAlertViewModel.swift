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
        let handler: (@MainActor (SQAlertContext?) -> Void)?  // ✅ pass context

        enum Role: Equatable { case normal, destructive, cancel }

        init(
            title: String,
            role: Role? = nil,
            shouldDismissOnTap: Bool = true,
            handler: (@MainActor (SQAlertContext?) -> Void)? = nil
        ) {
            self.title = title
            self.role = role
            self.shouldDismissOnTap = shouldDismissOnTap
            self.handler = handler
        }
        
        static let ok = Action(title: "OK")
    }

    let id: UUID
    let title: String
    let subtitle: String?
    let primary: Action
    let secondary: Action?
    let canDismiss: Bool
    let dropDown: SQAlertDropDownViewModel?
    
    @MainActor
    func buildContext() -> SQAlertContext? {
        .init(selectedDropDownId: dropDown?.selectedOptionId)
    }

    init(
        id: UUID = UUID(),
        title: String,
        subtitle: String? = nil,
        primary: Action,
        secondary: Action? = nil,
        canDismiss: Bool = false,
        dropDown: SQAlertDropDownViewModel? = nil
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.primary = primary
        self.secondary = secondary
        self.canDismiss = canDismiss
        self.dropDown = dropDown
    }
    
    init(_ sqError: SQUserFacingError, handler: (@MainActor (SQAlertContext?) -> Void)? = nil) { self.init(title: sqError.userFacingTitle, subtitle: sqError.userFacingDescription, primary: .init(title: "Got it", role: .cancel, handler: handler)) }

    static func == (lhs: SQAlertViewModel, rhs: SQAlertViewModel) -> Bool {
        // NOTE: dropDown is a reference type; don't include in Equatable
        lhs.id == rhs.id &&
        lhs.title == rhs.title &&
        lhs.subtitle == rhs.subtitle &&
        lhs.primary.title == rhs.primary.title &&
        lhs.primary.role == rhs.primary.role &&
        lhs.secondary?.title == rhs.secondary?.title &&
        lhs.secondary?.role == rhs.secondary?.role &&
        lhs.canDismiss == rhs.canDismiss
    }
}

struct SQAlertContext {
    let selectedDropDownId: String?
}
