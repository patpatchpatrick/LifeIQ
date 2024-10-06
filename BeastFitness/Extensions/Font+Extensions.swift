//
//  Font+Extensions.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 10/6/24.
//

import SwiftUI

extension Font {
    
    static func sqFont(_ type: SQFont.FontType) -> Font {
        .init(SQFont(type: type).font)
    }
}
