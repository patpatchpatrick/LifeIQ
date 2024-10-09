//
//  SQDeepLinkManager.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 10/8/24.
//

import Foundation

class SQDeepLinkManager {
    
    enum DeepLinkTypes: String {
        case stravaauth
    }
    
    func handleUriDeepLink(for url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
            SQLogger.shared.log("Invalid Deep Link Uri URL: \(url.absoluteString)", .error)
            return
        }
        
        guard let action = components.host else {
            SQLogger.shared.log("Unknown Deep Link Uri Host", .error)
            return
        }
        switch action {
        case DeepLinkTypes.stravaauth.rawValue:
            handleStravaDeepLink(components)
        default:
            return
        }
    }
    
    private func handleStravaDeepLink(_ components: URLComponents) {
        guard let code = components.queryItems?.first(where: { $0.name == "code" })?.value,
              let scope =  components.queryItems?.first(where: { $0.name == "scope" })?.value
        else {
            SQLogger.shared.log("Missing Expected Strava Auth components: code, scope", .error)
            return
        }
        
        SQStravaImport.shared.handleStravaAuthorization()
    }
    
}
