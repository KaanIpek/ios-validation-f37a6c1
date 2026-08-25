import XCTest
@testable import GroceryOS

final class AppConfigurationTests: XCTestCase {
    func testAcceptsPublicHTTPSConfiguration() throws {
        let configuration = try AppConfiguration.from(infoDictionary: [
            "GroceryWebBaseURL": "https://beta.grocery.example",
            "GroceryAppGroupIdentifier": "group.example.grocery",
        ])
        XCTAssertTrue(configuration.isSameOrigin(URL(string: "https://beta.grocery.example/basket")!))
        XCTAssertFalse(configuration.isSameOrigin(URL(string: "https://evil.example/basket")!))
    }

    func testRejectsLocalCleartextAndIPAddressHosts() {
        for candidate in [
            "http://grocery.example",
            "https://localhost:3000",
            "https://127.0.0.1",
            "https://192.168.1.20",
            "https://grocery.local",
            "https://grocery.example/unexpected-base-path",
        ] {
            XCTAssertThrowsError(
                try AppConfiguration.from(infoDictionary: [
                    "GroceryWebBaseURL": candidate,
                    "GroceryAppGroupIdentifier": "group.example.grocery",
                ])
            )
        }
    }

    func testRejectsUnexpandedReleasePlaceholders() {
        XCTAssertThrowsError(
            try AppConfiguration.from(infoDictionary: [
                "GroceryWebBaseURL": "$(GROCERY_WEB_BASE_URL)",
                "GroceryAppGroupIdentifier": "$(GROCERY_APP_GROUP_ID)",
            ])
        )
    }
}
