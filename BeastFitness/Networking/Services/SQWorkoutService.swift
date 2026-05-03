//
//  SQWorkoutService.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 12/13/25.
//

import Foundation
import FirebaseFirestore

struct SQWorkoutSyncDocument: Codable, Identifiable {
    let workoutId: String
    let remoteId: String
    let hkWorkoutId: String?
    let sourceRaw: String
    let title: String?
    let activityTypeRaw: Int
    let deviceRaw: String?
    let activeDuration: Double?
    let startDate: Date?
    let endDate: Date?
    let totalCalories: Double?
    let averageHeartRate: Double?
    let detailsData: Data?
    let reviewNotes: String?
    let ratingUserPerformance: Float?
    let ratingDifficulty: Float?
    let temperatureCelsius: Double?
    let createdAt: Date
    let updatedAt: Date
    let deletedAt: Date?

    var id: String { workoutId }
}

enum SQWorkoutRoute {
    case saveWorkout(SQWorkoutSyncDocument, user: SQUser)
    case fetchWorkouts(user: SQUser, afterDate: Date?)
}

extension SQWorkoutRoute: SQFirestoreRoute {
    var firestoreSafetyOperation: String {
        switch self {
        case .saveWorkout:
            return "save_workout_metadata"
        case .fetchWorkouts:
            return "fetch_workout_metadata"
        }
    }

    var writeBody: (any Encodable)? {
        switch self {
        case .saveWorkout(let workout, _):
            workout
        case .fetchWorkouts:
            nil
        }
    }

    func reference(in db: Firestore) -> SQFirestoreReference {
        switch self {
        case .saveWorkout(let workout, let user):
            return .documentWrite(
                db.collection("users")
                    .document(user.id)
                    .collection("workouts")
                    .document(workout.workoutId)
            )

        case .fetchWorkouts(let user, let afterDate):
            let collection = db.collection("users")
                .document(user.id)
                .collection("workouts")

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

protocol SQWorkoutServicing {
    static func saveWorkout(_ document: SQWorkoutSyncDocument, for user: SQUser) async throws
    static func fetchWorkouts(for user: SQUser, afterDate: Date?) async throws -> [SQWorkoutSyncDocument]
}

final class SQWorkoutService: SQNetworkService, SQWorkoutServicing {
    static func saveWorkout(_ document: SQWorkoutSyncDocument, for user: SQUser) async throws {
        let _: SQVoidWrite = try await performRequest(SQWorkoutRoute.saveWorkout(document, user: user))
        Task { @MainActor in
            SQFirestoreMetricsManager.shared.recordWrites(1, operation: "Save workout metadata")
        }
    }

    static func fetchWorkouts(for user: SQUser, afterDate: Date?) async throws -> [SQWorkoutSyncDocument] {
        try await performRequest(SQWorkoutRoute.fetchWorkouts(user: user, afterDate: afterDate))
    }
}
