import SwiftUI

enum SettingsTab: String, CaseIterable, Identifiable {
    case general = "General"
    case appearance = "Appearance"
    case debug = "Debug"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .general: "gearshape"
        case .appearance: "paintbrush"
        case .debug: "ladybug"
        }
    }
}

struct SettingsView: View {
    @Bindable var gateway: GatewayService

    var body: some View {
        TabView {
            GeneralSettingsView(gateway: gateway)
                .tabItem {
                    Label(SettingsTab.general.rawValue, systemImage: SettingsTab.general.icon)
                }
                .tag(SettingsTab.general)

            AppearanceSettingsView()
                .tabItem {
                    Label(SettingsTab.appearance.rawValue, systemImage: SettingsTab.appearance.icon)
                }
                .tag(SettingsTab.appearance)

            DebugSettingsView(gateway: gateway)
                .tabItem {
                    Label(SettingsTab.debug.rawValue, systemImage: SettingsTab.debug.icon)
                }
                .tag(SettingsTab.debug)
        }
        .frame(width: 500, height: 400)
    }
}

// MARK: - General

struct GeneralSettingsView: View {
    @Bindable var gateway: GatewayService

    @AppStorage("serverURL") private var savedURL: String = "ws://127.0.0.1:18789"
    @AppStorage("gatewayToken") private var savedToken: String = ""
    @AppStorage("enterSendsMessage") private var enterSendsMessage: Bool = true

    var body: some View {
        Form {
            Section("Input") {
                Toggle("Enter sends message", isOn: $enterSendsMessage)
                Text(enterSendsMessage
                     ? "Press Enter to send. Shift+Enter for new line."
                     : "Press Enter for new line. Click the send button to send.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Server") {
                TextField("WebSocket URL", text: $savedURL)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: savedURL) {
                        gateway.serverURL = savedURL
                    }

                SecureField("Gateway Token", text: $savedToken)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: savedToken) {
                        gateway.gatewayToken = savedToken
                    }
            }

            Section("Connection") {
                HStack {
                    Circle()
                        .fill(gateway.isConnected ? .green : .red)
                        .frame(width: 10, height: 10)
                    Text(gateway.isConnected ? "Connected" : "Disconnected")

                    Spacer()

                    if gateway.isConnected {
                        Button("Disconnect") {
                            gateway.disconnect()
                        }
                    } else {
                        Button("Connect") {
                            Task {
                                await gateway.connect()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }

                if let error = gateway.connectionError {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.caption)
                        .textSelection(.enabled)
                }
            }

        }
        .formStyle(.grouped)
        .onAppear {
            gateway.serverURL = savedURL
            gateway.gatewayToken = savedToken
        }
    }
}

// MARK: - Appearance

enum AppearanceMode: String, CaseIterable, Identifiable {
    case auto = "Auto"
    case light = "Light"
    case dark = "Dark"

    var id: String { rawValue }

    var colorScheme: ColorScheme? {
        switch self {
        case .auto: nil
        case .light: .light
        case .dark: .dark
        }
    }

    var icon: String {
        switch self {
        case .auto: "circle.lefthalf.filled"
        case .light: "sun.max"
        case .dark: "moon"
        }
    }
}

struct AppearanceSettingsView: View {
    @AppStorage("appearanceMode") private var appearanceMode: String = AppearanceMode.auto.rawValue
    @AppStorage("colorTheme") private var selectedTheme: String = ColorTheme.default_.rawValue

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 16), count: 4)

    var body: some View {
        Form {
            Section("Color Scheme") {
                Picker("Appearance", selection: $appearanceMode) {
                    ForEach(AppearanceMode.allCases) { mode in
                        Label(mode.rawValue, systemImage: mode.icon)
                            .tag(mode.rawValue)
                    }
                }
                .pickerStyle(.inline)
            }

            Section("Color Theme") {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(ColorTheme.allCases) { theme in
                        VStack(spacing: 6) {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(
                                    LinearGradient(
                                        colors: theme.gradientColors,
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 60, height: 60)
                                .overlay(alignment: .bottomTrailing) {
                                    if selectedTheme == theme.rawValue {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 16))
                                            .foregroundStyle(.white, .blue)
                                            .offset(x: 4, y: 4)
                                    }
                                }
                                .onTapGesture {
                                    selectedTheme = theme.rawValue
                                }

                            Text(theme.displayName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Debug

struct DebugSettingsView: View {
    @Bindable var gateway: GatewayService

    var body: some View {
        Form {
            Section("Connection") {
                HStack {
                    Circle()
                        .fill(gateway.isConnected ? .green : .red)
                        .frame(width: 10, height: 10)
                    Text(gateway.isConnected ? "Connected" : "Disconnected")
                }

                if let error = gateway.connectionError {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.caption)
                        .textSelection(.enabled)
                }
            }

            Section("Debug Log") {
                ScrollView {
                    Text(gateway.debugLog.isEmpty ? "No activity yet" : gateway.debugLog)
                        .font(.system(.caption, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
                .frame(height: 220)

                Button("Clear Log") {
                    gateway.debugLog = ""
                }
                .font(.caption)
            }
        }
        .formStyle(.grouped)
    }
}
