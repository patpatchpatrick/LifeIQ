//
//  Image+Extensions.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 2/2/26.
//

import SwiftUI

extension Image {

    func sqFont(_ type: SQFont.FontType) -> some View {
        self.font(.sqFont(type))
    }
}
