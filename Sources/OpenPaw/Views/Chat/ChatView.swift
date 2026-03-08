import SwiftUI
import SwiftData

struct ChatView: View {
    let conversation: Conversation
    let gateway: GatewayService

    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: ChatViewModel?

    var body: some View {
        VStack(spacing: 0) {
            messageList
            Divider()
            MessageInputView(
                isStreaming: viewModel?.isStreaming ?? false,
                isConnected: gateway.isConnected,
                onSend: { text in
                    viewModel?.send(text: text, in: conversation)
                },
                onStop: {
                    viewModel?.stop()
                }
            )
        }
        .navigationTitle(conversation.title)
        .onAppear {
            if viewModel == nil {
                viewModel = ChatViewModel(gateway: gateway, modelContext: modelContext)
            }
        }
        .onChange(of: conversation) {
            viewModel = ChatViewModel(gateway: gateway, modelContext: modelContext)
        }
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(conversation.sortedMessages) { message in
                        MessageBubbleView(
                            role: message.role,
                            content: message.content
                        )
                        .id(message.id)
                    }

                    // Streaming bubble
                    if let vm = viewModel, vm.isStreaming {
                        MessageBubbleView(
                            role: "assistant",
                            content: vm.streamingContent.isEmpty ? "…" : vm.streamingContent
                        )
                        .id("streaming")
                    }

                    // Error
                    if let error = viewModel?.error {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red)
                            Text(error)
                                .foregroundStyle(.red)
                                .font(.caption)
                        }
                        .padding(.horizontal)
                        .id("error")
                    }
                }
                .padding()
            }
            .onAppear {
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: conversation.messages.count) {
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: viewModel?.streamingContent) {
                scrollToBottom(proxy: proxy)
            }
        }
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.15)) {
            if let vm = viewModel, vm.isStreaming {
                proxy.scrollTo("streaming", anchor: .bottom)
            } else if let lastMsg = conversation.sortedMessages.last {
                proxy.scrollTo(lastMsg.id, anchor: .bottom)
            }
        }
    }
}
