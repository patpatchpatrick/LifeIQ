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
}
