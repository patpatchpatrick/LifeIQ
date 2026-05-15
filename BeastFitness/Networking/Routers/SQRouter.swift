//
//  SQRouter.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 12/1/25.
//

import FirebaseFirestore

/// This class is a hack.. It's used in SQNetworkService to allow us to keep our read and write routes under a single router
struct SQVoidWrite: Codable {}

protocol SQFirestoreRoute {
    func reference(in db: Firestore) -> SQFirestoreReference
    var writeBody: Encodable? { get } /// Only needed for write paths
    var firestoreSafetyOperation: String { get }
}

extension SQFirestoreRoute {
    var firestoreSafetyOperation: String {
        String(describing: Self.self)
    }
}

enum SQFirestoreReference {
    case documentRead(DocumentReference)
    case documentWrite(DocumentReference)
    case documentMerge(DocumentReference)
    case collection(CollectionReference)
    case query(Query)
}
