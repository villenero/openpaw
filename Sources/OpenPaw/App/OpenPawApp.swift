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
        .commands {
            CommandGroup(replacing: .newItem) { }
            CommandGroup(replacing: .appInfo) {
                Button("About OpenPaw") {
                    NSApp.orderFrontStandardAboutPanel(options: [
                        .applicationName: "OpenPaw",
                        .applicationVersion: "1.0",
                        .version: "Build: \(BuildInfo.timestamp)",
                        .credits: NSAttributedString(
                            string: "Built: \(BuildInfo.timestamp)",
                            attributes: [
                                .font: NSFont.systemFont(ofSize: 11),
                                .foregroundColor: NSColor.secondaryLabelColor
                            ]
                        )
                    ])
                }
            }
        }

        Settings {
            SettingsView(gateway: gateway)
        }
    }
}
