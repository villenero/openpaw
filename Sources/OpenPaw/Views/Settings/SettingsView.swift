import SwiftUI

struct SettingsView: View {
    @Bindable var gateway: GatewayService

    @AppStorage("serverURL") private var savedURL: String = "ws://127.0.0.1:18789"
    @AppStorage("gatewayToken") private var savedToken: String = ""

    var body: some View {
        Form {
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
        }
    }
}
