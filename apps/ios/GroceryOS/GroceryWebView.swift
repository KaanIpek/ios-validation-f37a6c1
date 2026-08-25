import SwiftUI
import UIKit
import WebKit

@MainActor
final class GroceryWebSession: NSObject, ObservableObject, WKNavigationDelegate {
    @Published private(set) var webView: WKWebView
    @Published private(set) var viewIdentity = UUID()
    @Published private(set) var isLoading = false
    @Published private(set) var lastError: String?

    private let appConfiguration: AppConfiguration
    private var authenticationFlowActive = false
    private static let retailerAuthenticationHosts: Set<String> = [
        "api.kroger.com",
        "login.kroger.com",
        "www.kroger.com",
    ]

    init(appConfiguration: AppConfiguration, retainsRetailerSessions: Bool) {
        self.appConfiguration = appConfiguration
        self.webView = Self.makeWebView(retainsRetailerSessions: retainsRetailerSessions)
        super.init()
        configureCurrentWebView()
        load(path: "/")
    }

    func rebuild(retainsRetailerSessions: Bool) {
        webView.navigationDelegate = nil
        webView = Self.makeWebView(retainsRetailerSessions: retainsRetailerSessions)
        viewIdentity = UUID()
        authenticationFlowActive = false
        configureCurrentWebView()
        load(path: "/")
    }

    func load(path: String) {
        guard let destination = URL(string: path, relativeTo: appConfiguration.baseURL)?.absoluteURL,
              appConfiguration.isSameOrigin(destination) else {
            lastError = "Grocery OS blocked an unsafe in-app destination."
            return
        }
        lastError = nil
        webView.load(URLRequest(url: destination, cachePolicy: .useProtocolCachePolicy))
    }

    func dismissError() { lastError = nil }

    func importSharedRecipe(_ payload: SharedRecipePayload) {
        var fragment = URLComponents()
        fragment.queryItems = [
            URLQueryItem(name: "title", value: payload.title),
            URLQueryItem(name: "text", value: payload.text),
            URLQueryItem(name: "url", value: payload.url),
        ]
        guard var destination = URLComponents(
            url: URL(string: "/import/social", relativeTo: appConfiguration.baseURL)!.absoluteURL,
            resolvingAgainstBaseURL: false
        ) else { return }
        destination.percentEncodedFragment = fragment.percentEncodedQuery
        guard let url = destination.url else { return }
        webView.load(URLRequest(url: url))
    }

    private func configureCurrentWebView() {
        webView.navigationDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        webView.customUserAgent = "GroceryOS-iOS/0.1"
    }

    private static func makeWebView(retainsRetailerSessions: Bool) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = retainsRetailerSessions ? .default() : .nonPersistent()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.preferences.isFraudulentWebsiteWarningEnabled = true
        configuration.userContentController.addUserScript(
            WKUserScript(
                source: "document.documentElement.dataset.nativeShell = 'ios';",
                injectionTime: .atDocumentStart,
                forMainFrameOnly: true
            )
        )
        return WKWebView(frame: .zero, configuration: configuration)
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        isLoading = true
        lastError = nil
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        isLoading = false
    }

    func webView(
        _ webView: WKWebView,
        didFailProvisionalNavigation navigation: WKNavigation!,
        withError error: Error
    ) {
        isLoading = false
        lastError = "The Grocery OS service could not be reached. Check your connection and try again."
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.cancel)
            return
        }

        if appConfiguration.isSameOrigin(url) {
            authenticationFlowActive = false
            decisionHandler(.allow)
            return
        }

        let host = url.host?.lowercased() ?? ""
        let beginsKrogerOAuth = host == "api.kroger.com" &&
            url.path.hasPrefix("/v1/connect/oauth2/authorize")
        if beginsKrogerOAuth { authenticationFlowActive = true }

        if url.scheme == "https",
           authenticationFlowActive,
           Self.retailerAuthenticationHosts.contains(host) {
            decisionHandler(.allow)
            return
        }

        if url.scheme == "https" {
            decisionHandler(.cancel)
            UIApplication.shared.open(url, options: [:])
            return
        }

        decisionHandler(.cancel)
    }
}

struct GroceryWebView: UIViewRepresentable {
    @ObservedObject var session: GroceryWebSession

    func makeUIView(context: Context) -> WKWebView { session.webView }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
