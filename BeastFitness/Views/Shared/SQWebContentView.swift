//
//  SQWebContentView.swift
//  BeastFitness
//
//  Created by Codex on 4/17/26.
//

import SwiftUI
import WebKit

struct SQWebContentView: View {
    @Environment(\.dismiss) private var dismiss

    let title: String
    let urlString: String

    @State private var isLoading = true
    @State private var loadErrorMessage: String?
    @State private var reloadToken = UUID()
    @State private var shouldDisplayWebView = false

    private var resolvedURL: URL? {
        URL(string: urlString)
    }

    var body: some View {
        Group {
            if let resolvedURL {
                ZStack {
                    if shouldDisplayWebView {
                        SQWebViewRepresentable(
                            url: resolvedURL,
                            isLoading: $isLoading,
                            loadErrorMessage: $loadErrorMessage,
                            reloadToken: reloadToken
                        )
                    }

                    if let loadErrorMessage {
                        errorState(message: loadErrorMessage)
                    } else if isLoading || !shouldDisplayWebView {
                        loadingState
                    }
                }
            } else {
                errorState(message: "This page could not be opened because the link is invalid.")
            }
        }
        .background {
            SQSheetBackground()
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(action: closeTapped) {
                    SQImageView(
                        image: .init(
                            symbol: .xMark,
                            symbolStyle: .colorWithFont(.textPrimary, font: .body)
                        )
                    )
                    .frame(width: 18, height: 18)
                }
                .buttonStyle(.plain)
            }
        }
        .task(id: resolvedURL?.absoluteString ?? "invalid-url") {
            guard resolvedURL != nil else { return }
            guard !shouldDisplayWebView else { return }

            await Task.yield()

            if !Task.isCancelled {
                shouldDisplayWebView = true
            }
        }
    }

    @ViewBuilder
    private var loadingState: some View {
        VStack(spacing: .SQSpace.m) {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(SQColor.accent(1).color)

            Text("Loading \(title)...")
                .sqFont(.bodyExtraSmall)
                .sqForegroundColor(.textSecondary)
        }
        .padding(.SQSpace.xl)
        .frame(maxWidth: 260)
        .sqGlassSurface(level: .card, cornerRadius: .SQCornerRadius.xl)
        .padding(.horizontal, .SQSpace.l)
    }

    @ViewBuilder
    private func errorState(message: String) -> some View {
        VStack(spacing: .SQSpace.m) {
            Text("Unable to Load Page")
                .sqFont(.title4)
                .sqForegroundColor(.textPrimary)

            Text(message)
                .sqFont(.bodyExtraSmall)
                .sqForegroundColor(.textSecondary)
                .multilineTextAlignment(.center)

            HStack(spacing: .SQSpace.s) {
                SQButton(style: .secondary, shouldHugContent: true, title: "Close") {
                    closeTapped()
                }

                if resolvedURL != nil {
                    SQButton(style: .glassPrimary, shouldHugContent: true, title: "Retry") {
                        loadErrorMessage = nil
                        isLoading = true
                        shouldDisplayWebView = false
                        reloadToken = UUID()
                    }
                }
            }
        }
        .padding(.SQSpace.l)
        .frame(maxWidth: 360)
        .sqGlassSurface(level: .card, cornerRadius: .SQCornerRadius.xl)
        .padding(.horizontal, .SQSpace.l)
    }

    private func closeTapped() {
        dismiss()
    }
}

private struct SQWebViewRepresentable: UIViewRepresentable {
    let url: URL
    @Binding var isLoading: Bool
    @Binding var loadErrorMessage: String?
    let reloadToken: UUID

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = SQWebViewManager.shared.makeConfiguration()
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.parent = self

        context.coordinator.loadIfNeeded(url: url, in: webView)
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        var parent: SQWebViewRepresentable
        var lastReloadToken: UUID
        private var lastRequestedURLString: String?

        init(parent: SQWebViewRepresentable) {
            self.parent = parent
            self.lastReloadToken = parent.reloadToken
        }

        func loadIfNeeded(url: URL, in webView: WKWebView) {
            let requestedURLString = url.absoluteString
            let shouldReloadForToken = lastReloadToken != parent.reloadToken
            let shouldLoadNewURL = lastRequestedURLString != requestedURLString

            guard shouldReloadForToken || shouldLoadNewURL else { return }

            lastReloadToken = parent.reloadToken
            lastRequestedURLString = requestedURLString
            setLoadingState(isLoading: true, errorMessage: nil)

            DispatchQueue.main.async {
                webView.load(URLRequest(url: url))
            }
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            setLoadingState(isLoading: true, errorMessage: nil)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            setLoadingState(isLoading: false, errorMessage: nil)
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            handle(error: error)
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            handle(error: error)
        }

        private func handle(error: Error) {
            let nsError = error as NSError
            if nsError.domain == NSURLErrorDomain, nsError.code == NSURLErrorCancelled {
                return
            }

            setLoadingState(isLoading: false, errorMessage: error.localizedDescription)
        }

        private func setLoadingState(isLoading: Bool, errorMessage: String?) {
            DispatchQueue.main.async {
                self.parent.isLoading = isLoading
                self.parent.loadErrorMessage = errorMessage
            }
        }
    }
}
