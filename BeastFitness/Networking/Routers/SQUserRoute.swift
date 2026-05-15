//
//  SQUserRoute.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 3/21/26.
//

import FirebaseFirestore

private struct SQUserSubscriptionLevelPatch: Encodable {
    let subscriptionLevel: SQSubscriptionLevel
}

enum SQUserRoute {
    case createUser(SQUser)
    case saveUser(SQUser)
    case updateSubscriptionLevel(uid: String, level: SQSubscriptionLevel)
    case fetchUser(uid: String)
}

extension SQUserRoute: SQFirestoreRoute {
    var firestoreSafetyOperation: String {
        switch self {
        case .createUser:
            return "create_user"
        case .saveUser:
            return "save_user"
        case .updateSubscriptionLevel:
            return "update_user_subscription_level"
        case .fetchUser:
            return "fetch_user"
        }
    }

    var writeBody: (any Encodable)? {
        switch self {
        case .createUser(let user):
            return user
        case .saveUser(let user):
            return user
        case .updateSubscriptionLevel(_, let level):
            return SQUserSubscriptionLevelPatch(subscriptionLevel: level)
        case .fetchUser:
            return nil
        }
    }

    func reference(in db: Firestore) -> SQFirestoreReference {
        switch self {
        case .createUser(let user):
            return .documentWrite(db.collection("users").document(user.id))
        case .saveUser(let user):
            return .documentWrite(db.collection("users").document(user.id))
        case .updateSubscriptionLevel(let uid, _):
            return .documentMerge(db.collection("users").document(uid))
        case .fetchUser(let uid):
            return .documentRead(db.collection("users").document(uid))
        }
    }
}
