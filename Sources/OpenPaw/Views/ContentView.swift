import SwiftUI
import SwiftData

struct ContentView: View {
    let gateway: GatewayService

    @Environment(\.modelContext) private var modelContext
    @State private var selectedConversation: Conversation?
    @AppStorage("lastConversationID") private var lastConversationID: String = ""

    var body: some View {
        NavigationSplitView {
            ConversationListView(
                selectedConversation: $selectedConversation,
                gateway: gateway
            )
            .navigationSplitViewColumnWidth(min: 200, ideal: 260, max: 400)
        } detail: {
            if let conversation = selectedConversation {
                ChatView(
                    conversation: conversation,
                    gateway: gateway
                )
            } else {
                ContentUnavailableView(
                    "No Chat Selected",
                    systemImage: "bubble.left.and.bubble.right",
                    description: Text("Select a conversation or create a new one")
                )
            }
        }
        .frame(minWidth: 700, minHeight: 500)
        .toolbar {
            ToolbarItem(placement: .automatic) {
                ConnectionStatusView(gateway: gateway)
            }
        }
        .onChange(of: selectedConversation) {
            if let id = selectedConversation?.id.uuidString {
                lastConversationID = id
            }
        }
        .onAppear {
            restoreLastConversation()
        }
    }

    private func restoreLastConversation() {
        guard !lastConversationID.isEmpty,
              let uuid = UUID(uuidString: lastConversationID) else { return }

        let descriptor = FetchDescriptor<Conversation>(
            predicate: #Predicate { $0.id == uuid }
        )
        if let conversation = try? modelContext.fetch(descriptor).first {
            selectedConversation = conversation
        }
    }
}

struct ConnectionStatusView: View {
    let gateway: GatewayService

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(gateway.isConnected ? .green : .red)
                .frame(width: 8, height: 8)

            if let error = gateway.connectionError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .lineLimit(1)
            } else {
                Text(gateway.isConnected ? "Connected" : "Disconnected")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !gateway.isConnected {
                Button("Connect") {
                    Task {
                        await gateway.connect()
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
    }
}
