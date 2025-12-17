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
    
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [] }
        
        var result: [[Element]] = []
        var index = 0
        
        while index < count {
            let end = Swift.min(index + size, count)
            result.append(Array(self[index..<end]))
            index += size
        }
        
        return result
    }
    
    mutating func appendIfNotNil(_ newElement: Element?) {
        if let newElement {
            self.append(newElement)
        }
    }
}
