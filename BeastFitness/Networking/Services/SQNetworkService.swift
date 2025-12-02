//
//  SQNetworkService.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 12/1/25.
//

import Foundation
import FirebaseFirestore

protocol SQNetworkServicing {
    static func performRequest<T: Codable>(_ route: SQFirestoreRoute) async throws -> T}

class SQNetworkService: SQNetworkServicing { }

extension SQNetworkService {
    
    static func performRequest<T>(_ route: any SQFirestoreRoute) async throws -> T where T : Decodable, T : Encodable {
        
        let db = Firestore.firestore()

           switch route.reference(in: db) {
           case .documentRead(let ref):
               let snap = try await ref.getDocument()
               return try snap.data(as: T.self)

           case .collection(let ref):
               let snaps = try await ref.getDocuments()
               return try snaps.documents.map { try $0.data(as: T.self) } as! T

           case .query(let q):
               let snaps = try await q.getDocuments()
               return try snaps.documents.map { try $0.data(as: T.self) } as! T

           case .documentWrite(let ref):
               guard let body = route.writeBody else {
                   fatalError("Write route must provide a body")
               }
               
               // 👇 HACK: assume this is used with T = SQVoidWrite so that we can use a single router for all calls
               guard T.self == SQVoidWrite.self else {
                   fatalError("Write routes should be called with T == SQVoidWrite")
               }

               try ref.setData(from: body)
               
               return SQVoidWrite() as! T
           }
    }
}
