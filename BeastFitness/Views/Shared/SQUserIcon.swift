//
//  SQUserIcon.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 12/8/25.
//

import SwiftUI

// PTD finish this view to load an actual image

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
    
    var body: some View {
        ZStack {
            Circle()
                .fill(SQColor.glassCardTint.color.opacity(SQColor.isDarkMode ? 0.84 : 0.96))
                .overlay(
                    Circle()
                        .stroke(SQColor.glassStroke.color, lineWidth: 1)
                )
            
            Text((user.name.first ?? .init("")).uppercased())
                .sqFont(monogramFont)
                .sqForegroundColor(.textPrimary)
        }
        .frame(width: size, height: size)
    }
}
