//
//  SQNetworkService.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 12/1/25.
//

import Foundation
import FirebaseFirestore
import BeastFitnessCore

protocol SQNetworkServicing {
    static func performRequest<T: Codable>(_ route: SQFirestoreRoute) async throws -> T}

class SQNetworkService: SQNetworkServicing { }

extension SQNetworkService {

    static func performRequest<T>(_ route: any SQFirestoreRoute) async throws -> T where T : Decodable, T : Encodable {

        let db = Firestore.firestore()
        let operation = route.firestoreSafetyOperation
        let firestoreReference = route.reference(in: db)

        switch firestoreReference {
        case .documentRead(let ref):
            try await SQFirestoreSafetyManager.shared.assertAllowed(
                kind: .read,
                operation: operation
            )
            let snap = try await ref.getDocument()
            try await SQFirestoreSafetyManager.shared.recordReads(1, operation: operation)
            return try snap.data(as: T.self)

        case .collection(let ref):
            try await SQFirestoreSafetyManager.shared.assertAllowed(
                kind: .read,
                operation: operation
            )
            let snaps = try await ref.getDocuments()
            try await SQFirestoreSafetyManager.shared.recordReads(
                max(snaps.documents.count, 1),
                operation: operation
            )
            return try decodeDocuments(snaps.documents, as: T.self)

        case .query(let q):
            try await SQFirestoreSafetyManager.shared.assertAllowed(
                kind: .read,
                operation: operation
            )
            let snaps = try await q.getDocuments()
            try await SQFirestoreSafetyManager.shared.recordReads(
                max(snaps.documents.count, 1),
                operation: operation
            )
            return try decodeDocuments(snaps.documents, as: T.self)

        case .documentWrite(let ref), .documentMerge(let ref):
            try await SQRemoteConfigManager.shared.assertServerWritesEnabled()
            try await SQFirestoreSafetyManager.shared.assertAllowed(
                kind: .write,
                operation: operation
            )

            guard let body = route.writeBody else {
                throw SQNetworkError.invalidResponseType(
                    expected: "body data",
                    got: "nil"
                )
            }

            guard T.self == SQVoidWrite.self else {
                throw SQNetworkError.invalidResponseType(
                    expected: "SQVoidWrite",
                    got: String(describing: T.self)
                )
            }

            let shouldMerge: Bool
            if case .documentMerge = firestoreReference {
                shouldMerge = true
            } else {
                shouldMerge = false
            }
            try await writeDocument(body, to: ref, merge: shouldMerge)
            try await SQFirestoreSafetyManager.shared.recordWrites(1, operation: operation)

            guard let result = SQVoidWrite() as? T else {
                throw SQNetworkError.invalidResponseType(
                    expected: String(describing: T.self),
                    got: "SQVoidWrite"
                )
            }
            return result
        }
    }

    /// Decodes an array of Firestore documents into the expected return type
    /// When T is an array type like [SomeModel], this decodes each document as the element type
    private static func decodeDocuments<T: Codable>(_ documents: [QueryDocumentSnapshot], as type: T.Type) throws -> T {
        do {
            // Use a wrapper to help with type inference
            let result = try decodeArray(documents: documents, targetType: type)
            guard let typedResult = result as? T else {
                let resultTypeName = String(reflecting: Swift.type(of: result))
                throw SQNetworkError.invalidResponseType(
                    expected: String(describing: T.self),
                    got: resultTypeName
                )
            }
            return typedResult
        } catch let error as SQNetworkError {
            throw error
        } catch {
            throw SQNetworkError.decodingFailed(underlying: error)
        }
    }

    /// Helper that uses a protocol witness to decode array elements
    private static func decodeArray<T>(documents: [QueryDocumentSnapshot], targetType: T.Type) throws -> Any {
        // Attempt to decode using a type-erased approach
        // We try to match common array types used in the app
        return try decodeTypedArray(documents, inferredFrom: targetType)
    }

    /// Attempts to decode documents as various known array types
    /// Uses compactMap to gracefully skip documents that don't conform to the current model
    private static func decodeTypedArray<T>(_ documents: [QueryDocumentSnapshot], inferredFrom type: T.Type) throws -> Any {
        let billedReadCount = max(documents.count, 1)

        // Try to decode as array of SQDailyCheckInStats (most common case)
        if type is [SQDailyCheckInStats].Type {
            let decoded = documents.compactMap { document -> SQDailyCheckInStats? in
                do {
                    return try document.data(as: SQDailyCheckInStats.self)
                } catch {
                    // Log the skipped document but don't fail the entire sync
                    SQLogger.shared.log(
                        "Skipping document '\(document.documentID)' - doesn't match current model: \(error.localizedDescription)",
                        .warning,
                        context: .dailyCheckIn
                    )
                    return nil
                }
            }

            // Track Firestore reads
            Task { @MainActor in
                SQFirestoreMetricsManager.shared.recordReads(
                    billedReadCount,
                    operation: "Fetch daily check-ins"
                )
            }

            return decoded
        }

        if type is [SQMetricDefinition].Type {
            let decoded = documents.compactMap { document -> SQMetricDefinition? in
                do {
                    return try document.data(as: SQMetricDefinition.self)
                } catch {
                    SQLogger.shared.log(
                        "Skipping document '\(document.documentID)' - doesn't match current model: \(error.localizedDescription)",
                        .warning,
                        context: .metricsManager
                    )
                    return nil
                }
            }

            // Track Firestore reads
            Task { @MainActor in
                SQFirestoreMetricsManager.shared.recordReads(
                    billedReadCount,
                    operation: "Fetch metric definitions"
                )
            }

            return decoded
        }

        if type is [SQMetricEntryBucket].Type {
            let decoded = documents.compactMap { document -> SQMetricEntryBucket? in
                do {
                    return try document.data(as: SQMetricEntryBucket.self)
                } catch {
                    SQLogger.shared.log(
                        "Skipping document '\(document.documentID)' - doesn't match current model: \(error.localizedDescription)",
                        .warning,
                        context: .dailyCheckIn
                    )
                    return nil
                }
            }

            Task { @MainActor in
                SQFirestoreMetricsManager.shared.recordReads(
                    billedReadCount,
                    operation: "Fetch metric entry buckets"
                )
            }

            return decoded
        }

        if type is [SQWorkoutSyncDocument].Type {
            let decoded = documents.compactMap { document -> SQWorkoutSyncDocument? in
                do {
                    return try document.data(as: SQWorkoutSyncDocument.self)
                } catch {
                    SQLogger.shared.log(
                        "Skipping workout document '\(document.documentID)' - doesn't match current model: \(error.localizedDescription)",
                        .warning,
                        context: .workoutManager
                    )
                    return nil
                }
            }

            Task { @MainActor in
                SQFirestoreMetricsManager.shared.recordReads(
                    billedReadCount,
                    operation: "Fetch workout metadata"
                )
            }

            return decoded
        }

        throw SQNetworkError.invalidResponseType(
            expected: "a supported array type",
            got: String(describing: type)
        )
    }

    private static func writeDocument(_ body: any Encodable, to reference: DocumentReference, merge: Bool = false) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            do {
                try reference.setData(from: body, merge: merge) { error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: ())
                    }
                }
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}
