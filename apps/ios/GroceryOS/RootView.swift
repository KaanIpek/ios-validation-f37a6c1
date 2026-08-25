import SwiftUI

private enum GroceryTask: String, CaseIterable, Identifiable {
    case home = "Home"
    case plan = "Plan"
    case basket = "Basket"
    case shop = "Shop"
    case profile = "Profile"

    var id: Self { self }
    var path: String {
        switch self {
        case .home: "/"
        case .plan: "/compare"
        case .basket: "/basket"
        case .shop: "/compare/kroger"
        case .profile: "/profile"
        }
    }
    var icon: String {
        switch self {
        case .home: "house"
        case .plan: "fork.knife"
        case .basket: "list.bullet.clipboard"
        case .shop: "cart"
        case .profile: "person.crop.circle"
        }
    }
}

private enum GroceryMenuDestination: String, CaseIterable, Identifiable {
    case importRecipe = "Import a recipe"
    case retailerLinks = "Retailer links"
    case foodSafety = "Food safety"
    case terms = "Terms & privacy"

    var id: Self { self }
    var path: String {
        switch self {
        case .importRecipe: "/import/social"
        case .retailerLinks: "/compare/shop"
        case .foodSafety: "/recalls"
        case .terms: "/legal/terms"
        }
    }
    var icon: String {
        switch self {
        case .importRecipe: "square.and.arrow.down"
        case .retailerLinks: "arrow.up.right.square"
        case .foodSafety: "checkmark.shield"
        case .terms: "doc.text"
        }
    }
}

struct RootView: View {
    let configuration: Result<AppConfiguration, Error>

    var body: some View {
        switch configuration {
        case .success(let appConfiguration):
            GroceryWorkspaceView(appConfiguration: appConfiguration)
        case .failure(let error):
            ContentUnavailableView(
                "Release configuration required",
                systemImage: "exclamationmark.shield",
                description: Text(error.localizedDescription)
            )
            .padding()
        }
    }
}

private struct GroceryWorkspaceView: View {
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("retainsRetailerSessions") private var retainsRetailerSessions = true
    @StateObject private var session: GroceryWebSession
    @State private var selectedTask = GroceryTask.home
    @State private var settingsPresented = false
    private let appConfiguration: AppConfiguration

    init(appConfiguration: AppConfiguration) {
        self.appConfiguration = appConfiguration
        _session = StateObject(
            wrappedValue: GroceryWebSession(
                appConfiguration: appConfiguration,
                retainsRetailerSessions: UserDefaults.standard.object(
                    forKey: "retainsRetailerSessions"
                ) as? Bool ?? true
            )
        )
    }

    var body: some View {
        NavigationStack {
            GroceryWebView(session: session)
                .id(session.viewIdentity)
                .overlay(alignment: .top) {
                    if session.isLoading { ProgressView().padding(8) }
                }
                .safeAreaInset(edge: .bottom, spacing: 0) { taskBar }
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        Label("Grocery OS", systemImage: "basket.fill")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(Color(red: 0.00, green: 0.21, blue: 0.15))
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Section("Grocery OS") {
                                ForEach(GroceryMenuDestination.allCases) { destination in
                                    Button {
                                        session.load(path: destination.path)
                                    } label: {
                                        Label(destination.rawValue, systemImage: destination.icon)
                                    }
                                }
                            }
                            Section {
                                Button {
                                    settingsPresented = true
                                } label: {
                                    Label("Settings", systemImage: "gearshape")
                                }
                            }
                        } label: {
                            Label("Menu", systemImage: "line.3.horizontal")
                        }
                    }
                }
                .toolbarBackground(Color(red: 0.94, green: 0.99, blue: 0.96), for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
                .toolbarColorScheme(.light, for: .navigationBar)
                .alert("Connection issue", isPresented: errorIsPresented) {
                    Button("Try again") { session.load(path: selectedTask.path) }
                    Button("Dismiss", role: .cancel) {}
                } message: {
                    Text(session.lastError ?? "The service could not be reached.")
                }
                .sheet(isPresented: $settingsPresented) { settingsSheet }
                .onOpenURL { url in
                    guard url.scheme == "groceryos", url.host == "import-shared-recipe" else { return }
                    consumePendingShare()
                }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { consumePendingShare() }
                }
        }
        .tint(Color(red: 0.04, green: 0.34, blue: 0.24))
        .preferredColorScheme(.light)
    }

    private var errorIsPresented: Binding<Bool> {
        Binding(
            get: { session.lastError != nil },
            set: { if !$0 { session.dismissError() } }
        )
    }

    private var taskBar: some View {
        HStack(spacing: 4) {
            ForEach(GroceryTask.allCases) { task in
                Button {
                    selectedTask = task
                    session.load(path: task.path)
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: task.icon)
                            .font(.system(size: 17, weight: .semibold))
                        Text(task.rawValue)
                            .font(.caption2.weight(.semibold))
                    }
                    .padding(.vertical, 7)
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(
                        selectedTask == task
                            ? Color(red: 0.00, green: 0.21, blue: 0.15)
                            : Color(red: 0.35, green: 0.40, blue: 0.37)
                    )
                    .background(
                        selectedTask == task
                            ? Color(red: 0.63, green: 0.96, blue: 0.79)
                            : Color.clear,
                        in: Capsule()
                    )
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selectedTask == task ? .isSelected : [])
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color(red: 0.985, green: 0.995, blue: 0.99))
        .overlay(alignment: .top) { Divider() }
    }

    private var settingsSheet: some View {
        NavigationStack {
            Form {
                Section("Retailer privacy") {
                    Toggle("Keep retailer sign-ins on this device", isOn: $retainsRetailerSessions)
                    Text(
                        retainsRetailerSessions
                            ? "Uses persistent on-device website storage. Sign-out and retailer controls still apply."
                            : "Uses an isolated session that is cleared when the app session is rebuilt."
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
                Section("Safety") {
                    Text("Grocery OS can prepare a retailer cart. It cannot submit an order or enable autobuy in this release.")
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { settingsPresented = false }
                }
            }
            .onChange(of: retainsRetailerSessions) { _, value in
                session.rebuild(retainsRetailerSessions: value)
                selectedTask = .home
            }
        }
    }

    private func consumePendingShare() {
        guard let payload = try? SharedRecipeStore(
            appGroupIdentifier: appConfiguration.appGroupIdentifier
        ).consume() else { return }
        selectedTask = .plan
        session.importSharedRecipe(payload)
    }
}
