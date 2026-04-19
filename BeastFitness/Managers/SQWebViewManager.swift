//
//  SQWebViewManager.swift
//  BeastFitness
//
//  Created by Codex on 4/17/26.
//

import Foundation
import WebKit

@MainActor
final class SQWebViewManager {
    static let shared = SQWebViewManager()

    private let processPool = WKProcessPool()

    private init() { }

    func makeConfiguration() -> WKWebViewConfiguration {
        let configuration = WKWebViewConfiguration()
        configuration.processPool = processPool
        configuration.websiteDataStore = .default()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        return configuration
    }
}
