import SwiftUI
import SwiftData

@main
struct OpenPawApp: App {
    let container: ModelContainer
    let gateway = GatewayService()

    init() {
        do {
            let schema = Schema([Conversation.self, Message.self])
            let config = ModelConfiguration("OpenPaw", isStoredInMemoryOnly: false)
            container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }

        // Load saved settings
        if let url = UserDefaults.standard.string(forKey: "serverURL"), !url.isEmpty {
            gateway.serverURL = url
        }
        if let token = UserDefaults.standard.string(forKey: "gatewayToken"), !token.isEmpty {
            gateway.gatewayToken = token
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView(gateway: gateway)
                .task {
                    if !gateway.serverURL.isEmpty && !gateway.gatewayToken.isEmpty {
                        await gateway.connect()
                    }
                }
        }
        .modelContainer(container)

        Settings {
            SettingsView(gateway: gateway)
        }
    }
}
