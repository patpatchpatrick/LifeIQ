//
//  SQDropDownButton.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 10/14/24.
//

import SwiftUI

struct SQDropDownButton: View {
    @ObservedObject var viewModel: SQButtonViewModel
    
    var content: some View {
        HStack(spacing: 4) {
            Text(viewModel.title)
                .sqFont(.body)
                .foregroundStyle(SQColor.text.color)
            
            SQImageView(image: .init(
                symbol: .chevronDown,
                symbolStyle: .init(
                    renderingMode: .palette,
                    multiColor: (.text, .text),
                    font: .init(type: .bodySmall)))
            )
            .frame(width: 10)
        }
    }
    
    var button: some View {
        Button(action: {
            viewModel.tapped()
        } ) {
            content
        }
    }
    
    var body: some View {
        button
            .padding(4)
            .sqBorder(.text, width: 1, cornerRadius: 4)
    }
}
