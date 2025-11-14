//
//  AttributedString+Extensions.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 11/13/25.
//

import SwiftUI

extension AttributedString {
    
    // Static method to build an AttributedString with font and color
    static func build(with text: String, font: Font? = nil, color: Color? = nil, backgroundColor: Color? = nil) -> AttributedString {
        var result = AttributedString(text)
        
        // Apply font if provided
        if let font = font {
            var attributes = AttributeContainer()
            attributes.font = font
            result.mergeAttributes(attributes)
        }
        
        // Apply text color if provided
        if let color = color {
            var attributes = AttributeContainer()
            attributes.foregroundColor = color
            result.mergeAttributes(attributes)
        }
        
        // Apply background color if provided
        if let backgroundColor = backgroundColor {
            var attributes = AttributeContainer()
            attributes.backgroundColor = backgroundColor
            result.mergeAttributes(attributes)
        }
        
        return result
    }
}
