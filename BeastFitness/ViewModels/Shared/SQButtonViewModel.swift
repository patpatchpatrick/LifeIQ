//
//  SQButtonViewModel.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 10/14/24.
//

import SwiftUI

final class SQButtonViewModel: ObservableObject, Identifiable {
    @Published var title: String
    let onTap: (() -> Void)?
    
    init(title: String, onTap: @escaping () -> Void) {
        self.title = title
        self.onTap = onTap
    }
    
    func tapped() {
        onTap?()
    }
}
