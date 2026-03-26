//
//  SQDropDownButton.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 10/14/24.
//

import SwiftUI

struct SQDropDownButton: View {
    @ObservedObject var viewModel: SQButtonViewModel
    var showBackground: Bool = true

    var content: some View {
        HStack(spacing: 4) {
            Text(viewModel.title)
                .sqFont(.body)
                .sqForegroundColor(.textPrimary)
            
            SQImageView(image: .init(
                symbol: .chevronDown,
                symbolStyle: .init(
                    renderingMode: .palette,
                    multiColor: (.textPrimary, .textPrimary),
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
            .padding(.horizontal, .SQSpace.m)
            .padding(.vertical, .SQSpace.s)
            .if(showBackground) {
                $0.sqGlassSurface(level: .card, cornerRadius: .SQCornerRadius.l)
            }
    }
}
