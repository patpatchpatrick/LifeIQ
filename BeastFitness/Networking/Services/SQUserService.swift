//
//  SQUserService.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 3/21/26.
//

import Foundation

final class SQUserService: SQNetworkService {

    static func createUser(uid: String, email: String) async throws -> SQUser {
        let user = SQUser(id: uid, name: "", email: email)
        let _: SQVoidWrite = try await performRequest(SQUserRoute.createUser(user))
        return user
    }

    static func fetchUser(uid: String) async throws -> SQUser {
        return try await performRequest(SQUserRoute.fetchUser(uid: uid))
    }
}
