//
//  SQImage.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 10/7/24.
//

import Foundation
import UIKit
import SwiftUI

struct SQImage {
    let type: ImageType
    let color: SQColor?
    let symbolStyle: SymbolStyle?
    let isResizable: Bool
    
    init(asset: ImageAsset? = nil, symbol: ImageSymbol? = nil, color: SQColor? = nil, symbolStyle: SymbolStyle? = nil, isResizable: Bool = true) {
        self.color = color
        self.symbolStyle = symbolStyle
        self.isResizable = isResizable
        if let asset {
            self.type = .asset(asset)
        }
        else if let symbol {
            self.type = .symbol(symbol)
        }
        else {
            fatalError("Must provide image metadata to SQImage.")
        }
    }
    
    var image: UIImage? {
        type.image
    }
    
    enum ImageType {
        case asset(ImageAsset)
        case symbol(ImageSymbol)
        
        var image: UIImage? {
            switch self {
            case .asset(let asset):
                return .init(named: asset.rawValue)
            case .symbol(let symbol):
                return .init(systemName: symbol.rawValue)
            }
        }
    }
    
    enum ImageAsset: String {
        case dumbell = "dumbell"
        case pickleball = "pickleball"
    }
    
    enum ImageSymbol: String {
        case bicycle = "bicycle"
        case chevronDown = "chevron.down"
        case figureWalk = "figure.walk"
        case questionmarkCircle = "questionmark.circle"
        
    }
    
    struct SymbolStyle {
        let renderingMode: SymbolRenderingMode
        let multiColor: (SQColor, SQColor)
        let font: SQFont?
        
        init(renderingMode: SymbolRenderingMode, multiColor: (SQColor, SQColor), font: SQFont? = nil) {
            self.renderingMode = renderingMode
            self.multiColor = multiColor
            self.font = font
        }
        
        static func colorWithFont(_ color: SQColor, _ color2: SQColor? = nil, font: SQFont.FontType) -> SymbolStyle
        {
            .init(renderingMode: .multicolor, multiColor: (color, color2 ?? color), font: .init(type: font))
        }
    }
}
