//
//  SQMetricDefinitionRoute.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 2/4/26.
//

import FirebaseFirestore

enum SQMetricDefinitionRoute {
    case saveMetricDefinition(SQMetricDefinition, SQUser)
    case fetchAllMetricDefinitions(SQUser, afterDate: Date?)
}

extension SQMetricDefinitionRoute: SQFirestoreRoute {
    var firestoreSafetyOperation: String {
        switch self {
        case .saveMetricDefinition:
            return "save_metric_definition"
        case .fetchAllMetricDefinitions:
            return "fetch_metric_definitions"
        }
    }

    var writeBody: (any Encodable)? {
        switch self {
        case .saveMetricDefinition(let definition, _):
            definition
        case .fetchAllMetricDefinitions:
            nil
        }
    }

    func reference(in db: Firestore) -> SQFirestoreReference {
        switch self {
        case .saveMetricDefinition(let definition, let user):
            return .documentWrite(
                db.collection("users")
                  .document(user.id)
                  .collection("metric-definitions")
                  .document(definition.id)
            )

        case .fetchAllMetricDefinitions(let user, let afterDate):
            let collection = db.collection("users")
                .document(user.id)
                .collection("metric-definitions")

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
