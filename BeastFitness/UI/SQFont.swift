//
//  SQFont.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 8/4/25.
//

import UIKit
import SwiftUI

struct SQFont {
    let type: FontType

    var uiFont: UIFont {
        switch type {
        case .title1, .title2, .title3, .title4,
                .body, .bodyLarge, .bodyBold, .bodySemiBold, .bodyItalic,
             .bodySmall, .bodySmallSemiBold, .bodySmallBold,
             .bodyExtraSmall, .buttonTitle, .faded,
             .headerSmall, .emojiLarge, .emojiToolbar, .emojiFeed:
            return type.makeUIFont()
        }
    }

    var font: Font { Font(uiFont) }

    enum FontType: CaseIterable {
        /// **22pt Bold** — Needs review.
        case title1
        /// **18pt Bold** — Home view title2.
        case title2
        /// **16pt Bold** — Home view title3.
        case title3
        /// **14pt Bold** — Home view title4.
        case title4
        /// **11pt Semibold**
        case headerSmall

        // MARK: - Body

        /// **14pt Regular**
        case body
        /// **16pt Regular**
        case bodyLarge
        /// **14pt Italic**
        case bodyItalic
        /// **14pt Bold**
        case bodyBold
        /// **14pt Semibold**
        case bodySemiBold

        /// **12pt Regular**
        case bodySmall
        /// **12pt Semibold**
        case bodySmallSemiBold
        /// **12pt Bold**
        case bodySmallBold
        /// **10pt Regular**
        case bodyExtraSmall
        /// **14pt Bold** — Button titles.
        case buttonTitle
        /// **11pt Regular** — Faded/secondary text.
        case faded

        // MARK: - Emoji / Decorative

        /// **80pt Bold**
        case emojiLarge
        /// **30pt Bold**
        case emojiToolbar
        /// **24pt Bold**
        case emojiFeed

        // Centralized definition so docs & implementation stay in sync.
        fileprivate var pointSize: CGFloat {
            switch self {
            case .title1: 22
            case .title2: 18
            case .title3, .bodyLarge: 16
            case .title4: 14
            case .headerSmall: 11

            case .body, .bodyItalic, .bodyBold, .bodySemiBold, .buttonTitle: 14
            case .faded: 11
            case .bodySmall, .bodySmallBold, .bodySmallSemiBold: 12
            case .bodyExtraSmall: 10

            case .emojiLarge: 80
            case .emojiToolbar: 30
            case .emojiFeed: 24
            }
        }

        fileprivate var weight: UIFont.Weight {
            switch self {
            case .title1, .title2, .title3, .title4,
                 .bodyBold, .bodySmallBold, .buttonTitle,
                 .emojiLarge, .emojiToolbar, .emojiFeed:
                return .bold
            case .bodySemiBold, .bodySmallSemiBold, .headerSmall:
                return .semibold
            default:
                return .regular
            }
        }

        fileprivate var isItalic: Bool {
            self == .bodyItalic
        }

        fileprivate func makeUIFont() -> UIFont {
            if isItalic {
                return .italicSystemFont(ofSize: pointSize)
            } else if weight == .bold {
                return .boldSystemFont(ofSize: pointSize)
            } else if weight == .regular {
                return .systemFont(ofSize: pointSize)
            } else {
                return .systemFont(ofSize: pointSize, weight: weight)
            }
        }
    }

    static func getAttributedText(
        text: String,
        font: UIFont? = nil,
        alignment: NSTextAlignment,
        color: UIColor
    ) -> NSAttributedString {
        let style = NSMutableParagraphStyle()
        style.alignment = alignment
        style.lineSpacing = 1.5
        let font = font ?? SQFont(type: .body).uiFont
        let attributes: [NSAttributedString.Key: Any] = [
            .paragraphStyle: style,
            .font: font,
            .foregroundColor: color
        ]
        return NSAttributedString(string: text, attributes: attributes)
    }
}
