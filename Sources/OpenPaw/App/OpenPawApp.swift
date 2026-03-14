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

    @AppStorage("appearanceMode") private var appearanceMode: String = AppearanceMode.auto.rawValue

    var body: some Scene {
        WindowGroup {
            ContentView(gateway: gateway)
                .preferredColorScheme(AppearanceMode(rawValue: appearanceMode)?.colorScheme)
                .task {
                    if !gateway.serverURL.isEmpty && !gateway.gatewayToken.isEmpty {
                        await gateway.connect()
                    }
                }
                .onAppear {
                    // Beta: show About panel on every launch
                    showAboutPanel()
                }
        }
        .modelContainer(container)
        .commands {
            CommandGroup(replacing: .newItem) { }
            CommandGroup(replacing: .appInfo) {
                Button("About OpenPaw") {
                    showAboutPanel()
                }
            }
        }

        Settings {
            SettingsView(gateway: gateway)
        }
    }

    private func showAboutPanel() {
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: "OpenPaw",
            .applicationVersion: "1.0 Beta",
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
