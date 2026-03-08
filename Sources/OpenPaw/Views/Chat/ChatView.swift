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

                    // Typing indicator
                    if let vm = viewModel, vm.isAgentProcessing && vm.streamingContent.isEmpty {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Assistant")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                                TypingIndicatorView()
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                    .background(Color(.controlBackgroundColor))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            Spacer(minLength: 60)
                        }
                        .id("typing")
                    }

                    // Streaming bubble
                    if let vm = viewModel, vm.isStreaming, !vm.streamingContent.isEmpty {
                        MessageBubbleView(
                            role: "assistant",
                            content: vm.streamingContent
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
            if let vm = viewModel, vm.isStreaming, !vm.streamingContent.isEmpty {
                proxy.scrollTo("streaming", anchor: .bottom)
            } else if let vm = viewModel, vm.isAgentProcessing {
                proxy.scrollTo("typing", anchor: .bottom)
            } else if let lastMsg = conversation.sortedMessages.last {
                proxy.scrollTo(lastMsg.id, anchor: .bottom)
            }
        }
    }
}
