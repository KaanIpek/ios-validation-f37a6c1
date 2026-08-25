import SwiftUI

@main
struct GroceryOSApp: App {
    private let configuration: Result<AppConfiguration, Error>

    init() {
        configuration = Result { try AppConfiguration.from() }
    }

    var body: some Scene {
        WindowGroup {
            RootView(configuration: configuration)
        }
    }
}

