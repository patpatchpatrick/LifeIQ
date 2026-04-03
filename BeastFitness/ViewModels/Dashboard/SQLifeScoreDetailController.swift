//
//  SQLifeScoreDetailController.swift
//  BeastFitness
//

import Foundation

@MainActor
@Observable final class SQLifeScoreDetailController: Identifiable {
    let id = UUID().uuidString
    let viewModel: SQLifeScoreViewModel

    init(viewModel: SQLifeScoreViewModel) {
        self.viewModel = viewModel
    }
}
