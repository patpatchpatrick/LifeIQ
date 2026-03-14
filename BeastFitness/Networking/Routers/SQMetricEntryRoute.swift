//
//  SQMetricEntryRoute.swift
//  BeastFitness
//

import FirebaseFirestore

enum SQMetricEntryRoute {
    /// Saves (writes) a single metric entry document for a user.
    case saveMetricEntry(SQMetricEntry, user: SQUser)
    /// Fetches all metric entries for a user, optionally after a date for incremental sync.
    case fetchMetricEntries(user: SQUser, afterDate: Date?)
}

extension SQMetricEntryRoute: SQFirestoreRoute {

    var writeBody: (any Encodable)? {
        switch self {
        case .saveMetricEntry(let entry, _):
            entry
        case .fetchMetricEntries:
            nil
        }
    }

    func reference(in db: Firestore) -> SQFirestoreReference {
        switch self {
        case .saveMetricEntry(let entry, let user):
            return .documentWrite(db.collection("users").document(user.id).collection("metric-entries").document(entry.id))

        case .fetchMetricEntries(let user, let afterDate):
            let collection = db.collection("users").document(user.id).collection("metric-entries")

            if let afterDate = afterDate {
                let query = collection
                    .whereField("recordedAt", isGreaterThan: afterDate)
                    .order(by: "recordedAt", descending: false)
                return .query(query)
            } else {
                return .collection(collection)
            }
        }
    }
}
