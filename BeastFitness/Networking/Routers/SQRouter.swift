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
}

enum SQFirestoreReference {
    case documentRead(DocumentReference)
    case documentWrite(DocumentReference)
    case collection(CollectionReference)
    case query(Query)
}
