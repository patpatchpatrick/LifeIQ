//
//  SQImage.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 10/7/24.
//

import SwiftUI

struct SQImageView: View {
    let image: SQImage
    
    var rootImage: Image {
        switch image.type {
        case .asset:
            return Image(uiImage: image.image!)
        case .symbol(let symbol):
            return Image(systemName: symbol.rawValue)
        }
    }
    
    var coreImage: Image {
        if image.isResizable {
            return rootImage
                .resizable()
        }
        else {
            return rootImage
        }
    }
    
    @ViewBuilder
    var filteredImage: some View {
        if let color = image.color {
            coreImage
                .renderingMode(.template)
                .foregroundColor(color.color)
        }
        else {
            coreImage
        }
    }
    
    @ViewBuilder
    var symbolAdjustedImage: some View {
        if let symbolStyle = image.symbolStyle {
            filteredImage
                .aspectRatio(contentMode: .fit)
                .symbolRenderingMode(symbolStyle.renderingMode)
                .foregroundStyle(symbolStyle.multiColor.0.color, symbolStyle.multiColor.1.color)
        }
        else {
            filteredImage
        }
    }
    
    @ViewBuilder
    var fontAdjustedImage: some View {
        if let font = image.symbolStyle?.font {
            symbolAdjustedImage.font(.sqFont(font.type))
        }
        else {
            symbolAdjustedImage
        }
    }
    
    var body: some View {
        fontAdjustedImage
    }
}
