//
//  SQStravaImport.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 10/8/24.
//

import Foundation
import SafariServices

final class SQStravaImport {
    static let shared = SQStravaImport()
    
    func getAllStravaActivitiesAndSaveToDocumentsDirectory(userAccessToken: String) async {
        var page = 1
        var allStravaActivities = [SQStravaWorkout]()
        while true {
            let stravaActivities = await getActivities(userAccessToken: userAccessToken, page: page)
            allStravaActivities.append(contentsOf: stravaActivities)
            if stravaActivities.isEmpty { break }
            page += 1
        }
        
        let filePath = getDocumentsDirectoryUrl().appendingPathComponent("beast-fitness-strava-activities-all-2.json")
        do {
            let jsonData = try JSONEncoder().encode(allStravaActivities)
            try jsonData.write(to: filePath)
        }
        catch {
            SQLogger.shared.log("Error Saving All Strava Activities: \(error.localizedDescription)", .error, context: .dataProcessing)
        }
    }
    
    /// Returns a list of activities (first 30)
    /// - Parameter userAccessToken: User's strava access token
    func getActivities(userAccessToken: String, page: Int) async -> [SQStravaWorkout] {
        var urlComponents = URLComponents(string: "https://www.strava.com/api/v3/athlete/activities")!

        let queryItems = [URLQueryItem(name: "access_token", value: userAccessToken),
                          URLQueryItem(name: "page", value: "\(page)")]

        urlComponents.queryItems = queryItems
        let token = userAccessToken
        var request = URLRequest(url: urlComponents.url!)
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.httpMethod = "GET"
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let stravaActivities = try JSONDecoder().decode([SQStravaWorkout].self, from: data)
            SQLogger.shared.log("Getting Strava Activities for page: \(page) count: \(stravaActivities.count)", .debug, context: .dataProcessing)
            return stravaActivities
        }
        catch {
            SQLogger.shared.log("Error decoding strava activities", .error, context: .dataProcessing)
            return []
        }
    }
    
    func handleStravaAuthorization(code: String) {
        requestAccessToken(uriCode: code)
    }
    
    /// Request Strava App Access, upon success, will deep link back into the app
    func requestAppAccess() {
        var authSession: SFAuthenticationSession?

        let appOAuthUrlStravaScheme = URL(string: "strava://oauth/mobile/authorize?client_id=137092&redirect_uri=beastfitness%3A%2F%2Fstravaauth%2Fen-US&response_type=code&approval_prompt=auto&scope=activity%3Aread%5Fall%2Cactivity%3Awrite%2Cread%5Fall&state=test")!

        let webOAuthUrl = URL(string: "https://www.strava.com/oauth/mobile/authorize?client_id=137092&redirect_uri= beastfitness%3A%2F%2Fstravaauth%2Fen-US&response_type=code&approval_prompt=auto&scope=activity%3Aread%5Fall%2Cactivity%3Awrite%2Cread%5Fall&state=test")!
        
        if UIApplication.shared.canOpenURL(appOAuthUrlStravaScheme) {
              UIApplication.shared.open(appOAuthUrlStravaScheme, options: [:])
          } else {
              authSession = SFAuthenticationSession(url: webOAuthUrl, callbackURLScheme: "beastfitness://stravaauth") { url, error in
                  // TODO: - PTD handle the URL from a web oAuthUrl the same as we are for the app OAuthUrl
//                  self.handleStravaAuthorization(code: <#T##String#>)
              }

              authSession?.start()
          }
    }
    
    
    /// Requests an access token from Strava for the URI code we received from Strava after we requested app access
    /// - Parameter uriCode: uriCode from Strava oAuth request
    func requestAccessToken(uriCode: String) {
        var urlComponents = URLComponents(string: "https://www.strava.com/api/v3/oauth/token")!

        let queryItems = [URLQueryItem(name: "client_id", value: "137092"),
                          URLQueryItem(name: "client_secret", value: "c23643f66aedfbe46efe9cc210ac672be663e89a"),
                          URLQueryItem(name: "code", value: uriCode),
                          URLQueryItem(name: "grant_type", value: "authorization_code")
        ]

        urlComponents.queryItems = queryItems
        
        let token = "a6a7f269fe0338719e071152a9bc92af72482e69"
        var request = URLRequest(url: urlComponents.url!)
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.httpMethod = "POST"
        URLSession.shared.dataTask(with: request) { (data, response , error) in
              guard let data = data else { return }
              do {
                  let stravaAuthData = try JSONSerialization.jsonObject(with: data) as? [AnyHashable: Any] ?? [:]
                  SQLogger.shared.log("Strava Auth Data: \(stravaAuthData)", .debug, context: .dataProcessing)
                  // TODO: - PTD Handle Storing the access token and refresh token in User Defaults and handling them appropriately.  DO NOT LOG Auth DATA IN PROD APP
              } catch let error {
                  // TODO: - PTD Handle errors appropriately
                  SQLogger.shared.log("Error requesting access token: \(error)", .error, context: .dataProcessing)
              }
          }.resume()
    }
    
    func getDocumentsDirectoryUrl() -> URL {
         let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
         let documentsDirectory = paths[0]
         return documentsDirectory
     }
    
    // TODO: - PTD remove this method
    func getSavedStravaWorkouts(_ timeRange: SQTimeRange) -> [SQWorkoutSessionable]? {
        let filePath = getDocumentsDirectoryUrl().appendingPathComponent("beast-fitness-strava-activities-all-2.json")
        
        do {
            let data = try Data(contentsOf: filePath)
            let workouts = try JSONDecoder().decode([SQStravaWorkout].self, from: data)
            let filteredWorkouts = workouts.filter { workout in
                return workout.endDate != nil && workout.endDate! > timeRange.startDate
            }
            return filteredWorkouts
                .map { SQWorkoutSource.stravaWorkout($0).buildWorkout(withOverrideData: nil) }
        }
        catch {
            return nil
        }
    }
}
