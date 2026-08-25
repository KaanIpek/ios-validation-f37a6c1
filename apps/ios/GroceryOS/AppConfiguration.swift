import Foundation

enum AppConfigurationError: LocalizedError, Equatable {
    case missingBaseURL
    case unsafeBaseURL
    case missingAppGroup

    var errorDescription: String? {
        switch self {
        case .missingBaseURL: "The release is missing its Grocery OS web address."
        case .unsafeBaseURL: "The configured Grocery OS address is not a safe public HTTPS origin."
        case .missingAppGroup: "The release is missing its signed App Group identifier."
        }
    }
}

struct AppConfiguration: Equatable, Sendable {
    let baseURL: URL
    let appGroupIdentifier: String

    static func from(infoDictionary: [String: Any] = Bundle.main.infoDictionary ?? [:]) throws -> Self {
        guard let rawBaseURL = infoDictionary["GroceryWebBaseURL"] as? String,
              !rawBaseURL.isEmpty else { throw AppConfigurationError.missingBaseURL }
        guard let baseURL = URL(string: rawBaseURL), isSafePublicHTTPSBaseURL(baseURL) else {
            throw AppConfigurationError.unsafeBaseURL
        }
        guard let appGroup = infoDictionary["GroceryAppGroupIdentifier"] as? String,
              appGroup.hasPrefix("group."), !appGroup.contains("$(") else {
            throw AppConfigurationError.missingAppGroup
        }
        return Self(baseURL: baseURL, appGroupIdentifier: appGroup)
    }

    func isSameOrigin(_ candidate: URL) -> Bool {
        candidate.scheme?.lowercased() == "https" &&
            candidate.host?.lowercased() == baseURL.host?.lowercased() &&
            effectivePort(candidate) == effectivePort(baseURL)
    }

    static func isSafePublicHTTPSBaseURL(_ url: URL) -> Bool {
        guard url.scheme?.lowercased() == "https",
              url.user == nil,
              url.password == nil,
              url.query == nil,
              url.fragment == nil,
              url.path.isEmpty || url.path == "/",
              let host = url.host?.lowercased(),
              !host.isEmpty,
              host != "localhost",
              !host.hasSuffix(".localhost"),
              !host.hasSuffix(".local"),
              !isIPAddress(host) else { return false }
        return true
    }

    private static func isIPAddress(_ host: String) -> Bool {
        if host.contains(":") { return true }
        let pieces = host.split(separator: ".")
        return pieces.count == 4 && pieces.allSatisfy { part in
            guard let number = Int(part) else { return false }
            return number >= 0 && number <= 255
        }
    }

    private func effectivePort(_ url: URL) -> Int { url.port ?? 443 }
}
