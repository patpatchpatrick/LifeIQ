//
//  SQUser.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 12/1/25.
//

struct SQUser: Codable {
    let id: String
    let name: String
    let email: String
}

// MARK: - Mock

extension SQUser {
    static let mock = SQUser(id: "mock", name: "Patrick Doyle", email: "patrick@example.com")
}


