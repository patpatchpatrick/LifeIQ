//
//  Double+Extensions.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 10/7/24.
//

import Foundation

extension Double? {
    
    var sqShortString: String {
        guard let doub = self else {
            return "N/A"
        }
        return doub.sqShortString
    }
}

extension Double {
    
    var sqShortString: String {
        return "\(self.sqStringRoundedTo(places: 2))"
    }
    
    func sqRoundedTo(places: Int) -> Double? {
        Double(sqStringRoundedTo(places: places))
    }
    
    func sqStringRoundedTo(places: Int) -> String {
        String(format: "%.\(places)f", self)
    }
}
