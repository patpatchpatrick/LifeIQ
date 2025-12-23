//
//  SQError.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 10/14/24.
//

import Foundation

struct SQError: SQUserFacingError {
    static let genericErrorTitle: String = "Error"
    static let genericErrorDescription: String = "Something went wrong."
    static let supportEmail = "support@beastfitness.com" //TODO: - PTD update this to be actual support email
    let title: String
    let description: String
    let underylingError: Error?
    
    init(title: String, description: String, underylingError: Error? = nil) {
        self.title = title
        self.description = description
        self.underylingError = underylingError
    }
    
    var userFacingTitle: String { title }
    var userFacingDescription: String { description }
    
    static let standard = SQError(title: Self.genericErrorTitle, description: Self.genericErrorDescription)
    static let standardConnection = SQError(title: Self.genericErrorTitle, description: "Something went wrong. Please check connection or try again later.")
    static func standard(withDescription description: String) -> SQError {
        .init(title: Self.standard.title, description: description)
    }
}

protocol SQUserFacingError: Error {
    var userFacingTitle: String { get }
    var userFacingDescription: String { get }
}

