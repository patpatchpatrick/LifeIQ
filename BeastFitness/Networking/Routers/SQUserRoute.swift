//
//  SQUserRoute.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 3/21/26.
//

import FirebaseFirestore

enum SQUserRoute {
    case createUser(SQUser)
    case fetchUser(uid: String)
}

extension SQUserRoute: SQFirestoreRoute {

    var writeBody: (any Encodable)? {
        switch self {
        case .createUser(let user):
            return user
        case .fetchUser:
            return nil
        }
    }

    func reference(in db: Firestore) -> SQFirestoreReference {
        switch self {
        case .createUser(let user):
            return .documentWrite(db.collection("users").document(user.id))
        case .fetchUser(let uid):
            return .documentRead(db.collection("users").document(uid))
        }
    }
}
