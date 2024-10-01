//
//  View+Extensions.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 9/30/24.
//

import SwiftUI

extension View {
    
    @ViewBuilder func redacted(_ isRedacted: Bool, reason: RedactionReasons) -> some View {
        if isRedacted {
            self.redacted(reason: reason)
        } else {
            self
        }
    }
    
}
