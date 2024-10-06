//
//  SQFont.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 10/6/24.
//

import UIKit

struct SQFont {
    let type: FontType
    
    var font: UIFont {
        switch type {
        case .title1:
            return .boldSystemFont(ofSize: 22)
        case .title2:
            return .boldSystemFont(ofSize: 18)
        case .title3:
            return .boldSystemFont(ofSize: 16)
        case .title4:
            return .boldSystemFont(ofSize: 14)
        case .body:
            return .systemFont(ofSize: 14)
        case .bodyItalic:
            return .italicSystemFont(ofSize: 14)
        case .bodyBold:
            return .boldSystemFont(ofSize: 14)
        case .bodySmall:
            return .systemFont(ofSize: 12)
        case .bodySmallBold:
            return .boldSystemFont(ofSize: 12)
        case .buttonTitle:
            return .boldSystemFont(ofSize: 14)
        case .faded:
            return .systemFont(ofSize: 11)
        case .emojiLarge:
            return .boldSystemFont(ofSize: 80)
        case .emojiToolbar:
            return .boldSystemFont(ofSize: 30)
        case .emojiFeed:
            return .boldSystemFont(ofSize: 24)
        }
    }
    
    enum FontType {
        case title1
        case title2
        case title3
        case title4
        case body
        case bodyItalic
        case bodyBold
        case bodySmall
        case bodySmallBold
        case buttonTitle
        case faded
        case emojiLarge
        case emojiToolbar
        case emojiFeed
    }
}
