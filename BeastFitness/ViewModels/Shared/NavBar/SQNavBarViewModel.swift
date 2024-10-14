//
//  SQNavBarViewModel.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 10/14/24.
//

import Foundation

final class SQNavBarViewModel: ObservableObject {
    let leadingViewModel: SQDropDownMenuViewModel
    @Published var allButtonsEnabled = true
    @Published var isVisible = true
    
    init(leadingViewModel: SQDropDownMenuViewModel) {
        self.leadingViewModel = leadingViewModel
    }
}
