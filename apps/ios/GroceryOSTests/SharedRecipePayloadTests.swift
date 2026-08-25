import XCTest
@testable import GroceryOS

final class SharedRecipePayloadTests: XCTestCase {
    func testBoundsAndSanitizesSharedValues() {
        let payload = SharedRecipePayload(
            title: String(repeating: "t", count: 250),
            text: "  two apples\u{0000}  ",
            url: String(repeating: "u", count: 2_100)
        )
        XCTAssertEqual(payload.title.count, SharedRecipePayload.maximumTitleLength)
        XCTAssertEqual(payload.text, "two apples")
        XCTAssertEqual(payload.url.count, SharedRecipePayload.maximumURLLength)
    }

    func testStoreConsumesPendingPayloadExactlyOnce() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = SharedRecipeStore(
            appGroupIdentifier: "group.test",
            containerURLProvider: { directory }
        )
        let payload = SharedRecipePayload(title: "Pie", text: "2 apples", url: nil)
        try store.save(payload)
        XCTAssertEqual(try store.consume(), payload)
        XCTAssertNil(try store.consume())
    }

    func testStoreRejectsEmptyPayload() {
        let store = SharedRecipeStore(
            appGroupIdentifier: "group.test",
            containerURLProvider: { FileManager.default.temporaryDirectory }
        )
        XCTAssertThrowsError(try store.save(SharedRecipePayload(title: nil, text: nil, url: nil)))
    }
}

