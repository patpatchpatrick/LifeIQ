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
    static let supportEmail = "support@lifeiq.app"
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
    static let notLoggedIn = SQError(title: "Not Logged In", description: "Please log in to continue.")
    static func standard(withDescription description: String) -> SQError {
        .init(title: Self.standard.title, description: description)
    }
}

protocol SQUserFacingError: Error {
    var userFacingTitle: String { get }
    var userFacingDescription: String { get }
}

enum SQNetworkError: SQUserFacingError {
    case invalidResponseType(expected: String, got: String)
    case decodingFailed(underlying: Error)

    var userFacingTitle: String {
        "Network Error"
    }

    var userFacingDescription: String {
        switch self {
        case .invalidResponseType(let expected, let got):
            return "Invalid response type: expected \(expected), got \(got)"
        case .decodingFailed(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        }
    }
}
