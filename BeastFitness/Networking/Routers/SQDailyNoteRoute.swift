//
//  SQDailyNoteRoute.swift
//  BeastFitness
//

import FirebaseFirestore

enum SQDailyNoteRoute {
    /// Saves (writes) a daily note document for a user.
    case saveDailyNote(SQDailyNote, user: SQUser)
    /// Fetches all daily notes for a user, optionally after a date for incremental sync.
    case fetchDailyNotes(user: SQUser, afterDate: Date?)
}

extension SQDailyNoteRoute: SQFirestoreRoute {

    var writeBody: (any Encodable)? {
        switch self {
        case .saveDailyNote(let note, _):
            note
        case .fetchDailyNotes:
            nil
        }
    }

    func reference(in db: Firestore) -> SQFirestoreReference {
        switch self {
        case .saveDailyNote(let note, let user):
            return .documentWrite(db.collection("users").document(user.id).collection("daily-notes").document(note.anchorDayKey))

        case .fetchDailyNotes(let user, let afterDate):
            let collection = db.collection("users").document(user.id).collection("daily-notes")

            if let afterDate = afterDate {
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
