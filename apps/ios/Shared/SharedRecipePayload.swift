import Foundation

struct SharedRecipePayload: Codable, Equatable, Sendable {
    static let maximumTitleLength = 200
    static let maximumTextLength = 12_000
    static let maximumURLLength = 2_048

    let title: String
    let text: String
    let url: String
    let receivedAt: Date

    init(title: String?, text: String?, url: String?, receivedAt: Date = Date()) {
        self.title = Self.bounded(title, limit: Self.maximumTitleLength)
        self.text = Self.bounded(text, limit: Self.maximumTextLength)
        self.url = Self.bounded(url, limit: Self.maximumURLLength)
        self.receivedAt = receivedAt
    }

    var isEmpty: Bool { title.isEmpty && text.isEmpty && url.isEmpty }

    private static func bounded(_ value: String?, limit: Int) -> String {
        let cleaned = (value ?? "")
            .replacingOccurrences(of: "\u{0000}", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return String(cleaned.prefix(limit))
    }
}

enum SharedRecipeStoreError: Error, Equatable {
    case appGroupUnavailable
    case emptyPayload
}

struct SharedRecipeStore {
    static let fileName = "pending-shared-recipe.plist"

    let appGroupIdentifier: String
    let fileManager: FileManager
    private let containerURLProvider: () -> URL?

    init(
        appGroupIdentifier: String,
        fileManager: FileManager = .default,
        containerURLProvider: (() -> URL?)? = nil
    ) {
        self.appGroupIdentifier = appGroupIdentifier
        self.fileManager = fileManager
        self.containerURLProvider = containerURLProvider ?? {
            fileManager.containerURL(
                forSecurityApplicationGroupIdentifier: appGroupIdentifier
            )
        }
    }

    func save(_ payload: SharedRecipePayload) throws {
        guard !payload.isEmpty else { throw SharedRecipeStoreError.emptyPayload }
        let destination = try payloadURL()
        let data = try PropertyListEncoder().encode(payload)
        try data.write(to: destination, options: [.atomic, .completeFileProtection])
    }

    /// Returns and deletes the one pending payload. A malformed payload is also
    /// deleted so an attacker cannot create an infinite launch loop.
    func consume() throws -> SharedRecipePayload? {
        let source = try payloadURL()
        guard fileManager.fileExists(atPath: source.path) else { return nil }
        defer { try? fileManager.removeItem(at: source) }
        return try PropertyListDecoder().decode(
            SharedRecipePayload.self,
            from: Data(contentsOf: source)
        )
    }

    private func payloadURL() throws -> URL {
        guard let container = containerURLProvider() else {
            throw SharedRecipeStoreError.appGroupUnavailable
        }
        return container.appendingPathComponent(Self.fileName, isDirectory: false)
    }
}
