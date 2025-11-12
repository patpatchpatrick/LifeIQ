//
//  Font+Extensions.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 10/6/24.
//

import SwiftUI

extension Font {
    /// Shorthand for your design-system fonts.
    ///
    /// Use like:
    /// ```swift
    /// Text("Title").font(.sqFont(.title2))
    /// ```
    /// - Parameter type: An `SQFont.FontType` (e.g. `.title2`). Quick Help for each case shows its point size & weight.
    static func sqFont(_ type: SQFont.FontType) -> Font {
        .init(SQFont(type: type).uiFont)
    }
}
