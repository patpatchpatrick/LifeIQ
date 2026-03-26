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
    
    var body: some View {
        ZStack {
            Circle()
                .fill(SQColor.glassCardTint.color.opacity(SQColor.isDarkMode ? 0.84 : 0.96))
                .overlay(
                    Circle()
                        .stroke(SQColor.glassStroke.color, lineWidth: 1)
                )
            
            Text((user.name.first ?? .init("")).uppercased())
                .sqFont(.bodySemiBold)
                .sqForegroundColor(.textPrimary)
        }
        .frame(width: 42, height: 42)
    }
}
