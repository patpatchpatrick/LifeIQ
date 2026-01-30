//
//  SQDailyCheckinRoute.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 12/1/25.
//

import FirebaseFirestore

enum SQDailyCheckInRoute {
    case saveDailyCheckIn(SQDailyCheckInStats, SQUser)
    case fetchAllDailyCheckIns(SQUser, afterDate: Date?)
}

extension SQDailyCheckInRoute: SQFirestoreRoute {

    var writeBody: (any Encodable)? {
        switch self {
        case .saveDailyCheckIn(let stats, _):
            stats
        case .fetchAllDailyCheckIns:
            nil
        }
    }

    func reference(in db: Firestore) -> SQFirestoreReference {
        switch self {
        case .saveDailyCheckIn(let stats, let user):
            return .documentWrite(db.collection("users").document(user.id).collection("daily-check-in-summaries").document(stats.date.firebaseDailyDateKey))

        case .fetchAllDailyCheckIns(let user, let afterDate):
            let collection = db.collection("users").document(user.id).collection("daily-check-in-summaries")

            if let afterDate = afterDate {
                // Incremental sync: only fetch documents after the last sync
                let query = collection
                    .whereField("date", isGreaterThan: afterDate)
                    .order(by: "date", descending: false)
                return .query(query)
            } else {
                // Initial sync: fetch all documents
                return .collection(collection)
            }
        }
    }
}
