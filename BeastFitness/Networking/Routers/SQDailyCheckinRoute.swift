//
//  SQDailyCheckinRoute.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 12/1/25.
//

import FirebaseFirestore

enum SQDailyCheckInRoute {
    case saveDailyCheckIn(SQDailyCheckInStats, SQUser)
}

extension SQDailyCheckInRoute: SQFirestoreRoute {
    
    var writeBody: (any Encodable)? {
        switch self {
        case .saveDailyCheckIn(let stats, _):
            stats
        }
    }
    
    func reference(in db: Firestore) -> SQFirestoreReference {
        switch self {
        case .saveDailyCheckIn(let stats, let user):
                .documentWrite(db.collection("users").document(user.id).collection("daily-check-in-summaries").document(stats.date.firebaseDailyDateKey))
        }
    }
}
