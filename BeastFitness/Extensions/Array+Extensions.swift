//
//  Array+Extensions.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 10/14/24.
//

import Foundation

extension Array {
    
    func appending(contentsOf: [Element]) -> [Element] {
        var newArray = [Element]()
        newArray.append(contentsOf: self)
        newArray.append(contentsOf: contentsOf)
        return newArray
    }
}
