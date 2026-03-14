//
//  SQMetricEntryRoute.swift
//  BeastFitness
//

import FirebaseFirestore

enum SQMetricEntryRoute {
    /// Saves (overwrites) the full daily bucket document for a user.
    case saveEntryBucket(SQMetricEntryBucket, user: SQUser)
    /// Fetches all daily bucket documents for a user, optionally after a date for incremental sync.
    case fetchEntryBuckets(user: SQUser, afterDate: Date?)
}

extension SQMetricEntryRoute: SQFirestoreRoute {

    var writeBody: (any Encodable)? {
        switch self {
        case .saveEntryBucket(let bucket, _):
            bucket
        case .fetchEntryBuckets:
            nil
        }
    }

    func reference(in db: Firestore) -> SQFirestoreReference {
        switch self {
        case .saveEntryBucket(let bucket, let user):
            return .documentWrite(
                db.collection("users").document(user.id).collection("metric-entries").document(bucket.anchorDayKey)
            )

        case .fetchEntryBuckets(let user, let afterDate):
            let collection = db.collection("users").document(user.id).collection("metric-entries")

            if let afterDate {
                let query = collection
                    .whereField("updatedAt", isGreaterThan: afterDate)
                    .order(by: "updatedAt", descending: false)
                return .query(query)
            } else {
                return .collection(collection)
            }
        }
    }
}
