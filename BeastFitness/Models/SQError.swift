//
//  SQError.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 10/14/24.
//

import Foundation

struct SQStandardError: SQUserFacingError {
    let title: String
    let description: String
    
    var userFacingTitle: String { title }
    var userFacingDescription: String { description }
    
    static let standard = SQStandardError(title: "Error", description: "Something went wrong.")
    static let standardConnection = SQStandardError(title: "Error", description: "Something went wrong. Please check connection or try again later.")
    static func standard(withDescription description: String) -> SQStandardError {
        .init(title: Self.standard.title, description: description)
    }
}

protocol SQUserFacingError: Error {
    var userFacingTitle: String { get }
    var userFacingDescription: String { get }
}

