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
    
    init(asset: ImageAsset? = nil, symbol: SQImageSymbol? = nil, color: SQColor? = nil, symbolStyle: SymbolStyle? = nil, isResizable: Bool = true) {
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
        case symbol(SQImageSymbol)
        
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
            .init(renderingMode: .palette, multiColor: (color, color2 ?? color), font: .init(type: font))
        }
    }
}

/// SF Symbols
enum SQImageSymbol: String {
    // General / fitness
    case questionmarkCircle = "questionmark.circle"
    case figureWalk          = "figure.walk"
    case figureRun           = "figure.run"
    case figureHiking        = "figure.hiking"
    case figureYoga          = "figure.yoga"
    case figurePilates       = "figure.pilates"
    case figureRowing        = "figure.rowing"
    case figureSwimming      = "figure.swimming"
    case figureElliptical    = "figure.elliptical"
    case figureStairs        = "figure.stairs"
    case figureStrength      = "figure.strengthtraining.traditional"
    case figureArchery       = "figure.archery"
    case figureCurling       = "figure.curling"
    case figureLacrosse      = "figure.lacrosse"
    case figurePickleball    = "figure.pickleball"
    case figureHandball      = "figure.handball"
    case figureDance         = "figure.dance"
    case figureEquestrian    = "figure.equestrian.sports"
    case figureFishing       = "figure.fishing"
    case figureHunting       = "figure.hunting"
    case figureCricket       = "figure.cricket"
    case figureDiscSports    = "figure.disc.sports"

    // Wheels & boats
    case bicycle             = "bicycle"
    case sailboat            = "sailboat"

    // Winter & board sports
    case figureSkiing        = "figure.skiing.downhill"
    case figureSnowboarding  = "figure.snowboarding"
    case figureSkating       = "figure.skating" // if unavailable, will fallback upstream

    // Balls & sticks
    case soccerball          = "soccerball"
    case basketball          = "basketball"
    case baseball            = "baseball"
    case volleyball          = "volleyball"
    case football            = "football"          // American football
    case rugbyball           = "rugbyball"         // if unavailable, we’ll fallback upstream
    case tennisRacket        = "tennis.racket"
    case tableTennisPaddle   = "table.tennis.paddle"
    case badminton           = "figure.badminton"
    case hockeyPuck          = "hockey.puck"
    case bowlingBall         = "bowlingball"
    case golf                = "figure.golf"

    // Misc sports
    case fencing             = "figure.fencing"
    case surfing             = "figure.surfing"
    case climbing            = "figure.climbing"
    case boxing              = "figure.boxing"
    case handCycling         = "figure.hand.cycling" // wheelchair hand-cycling alt
    case wheelchairWalkPace  = "figure.roll"         // generic fallback for wheelchair
    
    /// Other
    case chevronDown         = "chevron.down"
    case checkmark           = "checkmark"
}
