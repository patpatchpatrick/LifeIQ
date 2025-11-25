//
//  Text+Extensions.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 10/6/24.
//

import SwiftUI

extension Text {
    
    func sqFont(_ type: SQFont.FontType) -> Text {
        self.font(.sqFont(type))
    }
    
    @ViewBuilder
    func sqShadow() -> some View {
        self.shadow(color: .black.opacity(0.25), radius: 2, x: 0, y: 1)
    }
}
