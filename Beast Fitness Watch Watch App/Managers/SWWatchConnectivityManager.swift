//
//  SWWatchConnectivityManager.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 12/30/25.
//

import WatchConnectivity
import BeastFitnessCore

protocol SWWatchConnectivityManaging {}

final class SWWatchConnectivityManager: NSObject, ObservableObject, SWWatchConnectivityManaging {
    @Published var workoutPayload: SQWatchWorkoutPayload? = nil
    
    static let shared = SWWatchConnectivityManager()

    override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }
    
    // MARK: - Decode helper

    nonisolated private func handleIncoming(message: [String: Any]) {
        
        SQLogger.shared.logW("Received incoming message from iOS: \(message)", .debug, context: .watchInterface)
        
        do {
            let payload = try SQWatchWorkoutPayload.fromWCMessage(message)
            Task { @MainActor in
                self.workoutPayload = payload
                SWAppState.shared.rootState.updateActiveWorkoutDescription(to: payload.visibleDescription)
            }
        } catch {
            // TODO: - PTD Deprecated surface error to user when we can't decode the payload from iOS?
            SQLogger.shared.logW("Failed to decode workout payload: \(error.localizedDescription)", .error, context: .watchInterface)
        }
    }
}

// MARK: - WCSessionDelegate (watchOS)

extension SWWatchConnectivityManager: WCSessionDelegate {

      nonisolated func session(
          _ session: WCSession,
          activationDidCompleteWith activationState: WCSessionActivationState,
          error: Error?
      ) {
          if let error {
              // TODO: - PTD Deprecated surface error to user when we can't activate session
              SQLogger.shared.logW("Failed to activate watch session: \(error.localizedDescription)", .error, context: .watchInterface)
          }
      }

      /// iPhone used updateApplicationContext
      nonisolated func session(
          _ session: WCSession,
          didReceiveApplicationContext applicationContext: [String : Any]
      ) {
          handleIncoming(message: applicationContext)
      }

      /// iPhone used sendMessage
      nonisolated func session(
          _ session: WCSession,
          didReceiveMessage message: [String : Any]
      ) {
          handleIncoming(message: message)
      }
}
