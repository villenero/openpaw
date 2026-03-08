import SwiftUI
import SwiftData

struct ConversationListView: View {
    @Binding var selectedConversation: Conversation?
    let gateway: GatewayService

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Conversation.updatedAt, order: .reverse)
    private var conversations: [Conversation]

    var body: some View {
        List(selection: $selectedConversation) {
            ForEach(conversations) { conversation in
                ConversationRowView(conversation: conversation)
                    .tag(conversation)
                    .contextMenu {
                        Button("Delete", role: .destructive) {
                            if selectedConversation == conversation {
                                selectedConversation = nil
                            }
                            modelContext.delete(conversation)
                            try? modelContext.save()
                        }
                    }
            }
        }
        .listStyle(.sidebar)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: createNewChat) {
                    Image(systemName: "plus")
                }
                .keyboardShortcut("n", modifiers: .command)
                .help("New Chat")
            }
        }
        .navigationTitle("Chats")
    }

    private func createNewChat() {
        let conversation = Conversation()
        modelContext.insert(conversation)
        try? modelContext.save()
        selectedConversation = conversation
    }
}
