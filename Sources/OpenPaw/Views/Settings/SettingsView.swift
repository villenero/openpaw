import SwiftUI

struct SettingsView: View {
    @Bindable var gateway: GatewayService

    @AppStorage("serverURL") private var savedURL: String = "ws://127.0.0.1:18789"
    @AppStorage("gatewayToken") private var savedToken: String = ""
    @AppStorage("enterSendsMessage") private var enterSendsMessage: Bool = true
    @AppStorage("userBubbleColor") private var userBubbleHex: String = BubbleColors.defaultUserHex
    @AppStorage("assistantBubbleColor") private var assistantBubbleHex: String = BubbleColors.defaultAssistantHex

    @State private var userColor: Color = BubbleColors.defaultUser
    @State private var assistantColor: Color = BubbleColors.defaultAssistant

    var body: some View {
        Form {
            Section("Appearance") {
                ColorPicker("User bubble", selection: $userColor, supportsOpacity: false)
                    .onChange(of: userColor) {
                        userBubbleHex = userColor.toHex()
                    }
                ColorPicker("Assistant bubble", selection: $assistantColor, supportsOpacity: false)
                    .onChange(of: assistantColor) {
                        assistantBubbleHex = assistantColor.toHex()
                    }
                Button("Reset to defaults") {
                    userColor = BubbleColors.defaultUser
                    assistantColor = BubbleColors.defaultAssistant
                    userBubbleHex = BubbleColors.defaultUserHex
                    assistantBubbleHex = BubbleColors.defaultAssistantHex
                }
                .font(.caption)
            }

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

            Section("Debug Log") {
                ScrollView {
                    Text(gateway.debugLog.isEmpty ? "No activity yet" : gateway.debugLog)
                        .font(.system(.caption, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
                .frame(height: 200)
            }
        }
        .formStyle(.grouped)
        .frame(width: 500, height: 500)
        .padding()
        .onAppear {
            gateway.serverURL = savedURL
            gateway.gatewayToken = savedToken
            userColor = Color(hex: userBubbleHex) ?? BubbleColors.defaultUser
            assistantColor = Color(hex: assistantBubbleHex) ?? BubbleColors.defaultAssistant
        }
    }
}
