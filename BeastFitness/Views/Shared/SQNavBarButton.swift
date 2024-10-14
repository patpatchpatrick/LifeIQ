//
//  SQNavBarButton.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 10/14/24.
//

import SwiftUI

struct SQNavBarButton: View {
    @ObservedObject var viewModel: SQButtonViewModel
    
    var content: some View {
        Text(viewModel.title)
            .sqFont(.body)
            .foregroundStyle(SQColor.text.color)
    }
    
    var body: some View {
        Button(action: {
            viewModel.tapped()
        } ) {
            content
        }
    }
}
