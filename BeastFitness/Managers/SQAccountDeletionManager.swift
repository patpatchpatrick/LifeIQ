//
//  SQAccountDeletionManager.swift
//  BeastFitness
//
//  Created by OpenAI on 4/7/26.
//

import Foundation
import FirebaseFirestore
import SwiftData
import BeastFitnessCore

enum SQAccountDeletionError: SQUserFacingError {
    case notLoggedIn
    case passwordRequired
    case authDeletionFailed

    var userFacingTitle: String {
        switch self {
        case .notLoggedIn:
            return "Delete Account"
        case .passwordRequired:
            return "Password Required"
        case .authDeletionFailed:
            return "Delete Account"
        }
    }

    var userFacingDescription: String {
        switch self {
        case .notLoggedIn:
            return "You need to be signed in to delete your account."
        case .passwordRequired:
            return "Enter your current password to continue."
        case .authDeletionFailed:
            return "Your LifeIQ data was removed, but we could not finish deleting the sign-in account. Please try again, or contact support if the issue continues."
        }
    }
}

@MainActor
protocol SQAccountDeletionManaging: AnyObject {
    func deleteAccount(
        for user: SQUser,
        reauthenticationMethod: SQAccountDeletionReauthenticationMethod,
        modelContext: ModelContext
    ) async throws
}

@MainActor
final class SQAccountDeletionManager: SQAccountDeletionManaging {
    static let shared = SQAccountDeletionManager()

    private let authManager: SQAuthManaging
    private let firestore: Firestore
    private let subcollections = [
        "daily-check-in-summaries",
        "metric-definitions",
        "metric-entries",
        "workouts"
    ]

    init(
        authManager: SQAuthManaging = SQAuthManager.shared,
        firestore: Firestore = Firestore.firestore()
    ) {
        self.authManager = authManager
        self.firestore = firestore
    }

    func deleteAccount(
        for user: SQUser,
        reauthenticationMethod: SQAccountDeletionReauthenticationMethod,
        modelContext: ModelContext
    ) async throws {
        try await authManager.reauthenticateForAccountDeletion(using: reauthenticationMethod)

        if authManager.currentAuthProviders().contains(.google) {
            do {
                try await authManager.revokeGoogleAccessIfNeeded()
            } catch {
                SQLogger.shared.log(
                    "Google access revocation failed before account deletion for \(user.id): \(error.localizedDescription)",
                    .warning,
                    context: .network
                )
            }
        }

        try await deleteRemoteData(for: user)

        do {
            try await authManager.deleteCurrentUser()
        } catch {
            SQLogger.shared.log(
                "Account deletion failed while deleting Firebase Auth user \(user.id): \(error.localizedDescription)",
                .error,
                context: .network,
                isPriority: true
            )
            throw SQAccountDeletionError.authDeletionFailed
        }

        await clearLocalData(for: user, modelContext: modelContext)

        try? authManager.signOut()

        let appState = SQAppState.shared
        appState.userState.setLoggedOut()
        appState.hub.domainEvents.send(.dismissDashboardNavStack)
        appState.hub.metricEvents.send(.metricsUpdated)
        appState.hub.toastEvents.send(.present(.init(title: "Account deleted", style: .success)))
    }

    private func deleteRemoteData(for user: SQUser) async throws {
        try SQRemoteConfigManager.shared.assertServerWritesEnabled()

        let userRef = firestore.collection("users").document(user.id)

        for subcollection in subcollections {
            try await deleteCollection(userRef.collection(subcollection), named: subcollection)
        }

        let snapshot = try await userRef.getDocument()
        SQFirestoreMetricsManager.shared.recordReads(1, operation: "Account deletion fetch user document")

        guard snapshot.exists else { return }

        let batch = firestore.batch()
        batch.deleteDocument(userRef)
        try await batch.commit()
        SQFirestoreMetricsManager.shared.recordWrites(1, operation: "Account deletion delete user document")
    }

    private func deleteCollection(_ collection: CollectionReference, named name: String) async throws {
        while true {
            let snapshot = try await collection.limit(to: 200).getDocuments()
            let documents = snapshot.documents

            guard !documents.isEmpty else { return }

            SQFirestoreMetricsManager.shared.recordReads(
                documents.count,
                operation: "Account deletion fetch \(name)"
            )

            let batch = firestore.batch()
            for document in documents {
                batch.deleteDocument(document.reference)
            }

            try await batch.commit()
            SQFirestoreMetricsManager.shared.recordWrites(
                documents.count,
                operation: "Account deletion delete \(name)"
            )
        }
    }

    private func clearLocalData(for user: SQUser, modelContext: ModelContext) async {
        deleteAll(SQDailyCheckInSessionEntity.self, from: modelContext)
        deleteAll(SQWorkoutSessionEntity.self, from: modelContext)
        deleteAll(SQMetricDefinitionEntity.self, from: modelContext)
        deleteAll(SQSyncMetadataEntity.self, from: modelContext)
        deleteAll(SQWorkoutProcessedEntity.self, from: modelContext)
        deleteAll(SQMetricEntryEntity.self, from: modelContext)
        deleteAll(SQDailyNoteEntity.self, from: modelContext)

        try? modelContext.save()

        SQUserDefaults.shared.clearAccountScopedData(for: user.id)
        SQMetricDefinitionManager.shared.reset()
        SQHealthKitManager.shared.invalidateCache()
        await SQWorkoutSessionMetadataManager.shared.invalidate()

        let dashboardState = SQAppState.shared.dashboardState
        dashboardState.updateSectionGroups(to: [])
        dashboardState.updateAvailableLayoutGroups([])
        dashboardState.updateUncustomizedSectionGroups([])
        dashboardState.updateDailyCheckInCtaViewModel(nil)
        dashboardState.setLoading(false)
    }

    private func deleteAll<T: PersistentModel>(_ type: T.Type, from context: ModelContext) {
        let descriptor = FetchDescriptor<T>()
        let objects = (try? context.fetch(descriptor)) ?? []
        for object in objects {
            context.delete(object)
        }
    }
}
