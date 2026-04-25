//
//  SQButtonViewModel.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 10/14/24.
//

import SwiftUI

final class SQButtonViewModel: ObservableObject, Identifiable {
    @Published var title: String
    @Published var showsIndicatorDot: Bool
    let onTap: (() -> Void)?
    
    init(
        title: String,
        showsIndicatorDot: Bool = false,
        onTap: @escaping () -> Void
    ) {
        self.title = title
        self.showsIndicatorDot = showsIndicatorDot
        self.onTap = onTap
    }
    
    func tapped() {
        onTap?()
    }
}
