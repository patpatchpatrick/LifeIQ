//
//  SQUserIcon.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 12/8/25.
//

import SwiftUI

struct SQUserIcon: View {
    let user: SQUser
    let size: CGFloat

    init(user: SQUser, size: CGFloat = 42) {
        self.user = user
        self.size = size
    }

    private var monogramFont: SQFont.FontType {
        switch size {
        case 72...:
            return .title1
        case 56...:
            return .title2
        case 44...:
            return .title3
        default:
            return .bodySemiBold
        }
    }

    private var monogramText: String {
        let preferredSource = user.fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallbackSource = user.email.trimmingCharacters(in: .whitespacesAndNewlines)
        let source = preferredSource.isEmpty ? fallbackSource : preferredSource

        guard let firstCharacter = source.first else {
            return "?"
        }

        return String(firstCharacter).uppercased()
    }
    
    var body: some View {
        ZStack {
            Circle()
                .fill(SQColor.glassCardTint.color.opacity(SQColor.isDarkMode ? 0.84 : 0.96))
                .overlay(
                    Circle()
                        .stroke(SQColor.glassStroke.color, lineWidth: 1)
                )
            
            Text(monogramText)
                .sqFont(monogramFont)
                .sqForegroundColor(.textPrimary)
        }
        .frame(width: size, height: size)
    }
}
