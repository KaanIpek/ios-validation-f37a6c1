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
                    ToolbarItem(placement: .topBarLeading) {
                        Text("Grocery OS").font(.headline)
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Settings", systemImage: "gearshape") {
                            settingsPresented = true
                        }
                    }
                }
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
                        Text(task.rawValue).font(.caption2)
                    }
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(selectedTask == task ? Color.accentColor : .secondary)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selectedTask == task ? .isSelected : [])
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 9)
        .background(.regularMaterial)
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
