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
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(conversation.sortedMessages) { message in
                        MessageBubbleView(
                            role: message.role,
                            content: message.content,
                            media: message.mediaItems
                        )
                        .id(message.id)
                    }

                    // Typing indicator
                    if let vm = viewModel, vm.isAgentProcessing && vm.displayedContent.isEmpty && vm.streamingMedia.isEmpty {
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
                    if let vm = viewModel, vm.isStreaming,
                       (!vm.displayedContent.isEmpty || !vm.streamingMedia.isEmpty) {
                        MessageBubbleView(
                            role: "assistant",
                            content: vm.displayedContent,
                            media: vm.streamingMedia,
                            isStreamingFade: !vm.isStreamingFinalized
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
                scrollToBottom(proxy: proxy, animated: false)
            }
            .onChange(of: conversation) {
                // Delay to next run loop so VStack has rendered the new messages
                DispatchQueue.main.async {
                    scrollToBottom(proxy: proxy, animated: false)
                }
            }
            .onChange(of: conversation.messages.count) {
                scrollToBottom(proxy: proxy, animated: true)
            }
            .onChange(of: viewModel?.displayedContent) {
                scrollToBottom(proxy: proxy, animated: true)
            }
        }
    }

    private func scrollToBottom(proxy: ScrollViewProxy, animated: Bool) {
        let target: AnyHashable? = {
            if let vm = viewModel, vm.isStreaming, !vm.displayedContent.isEmpty {
                return "streaming"
            } else if let vm = viewModel, vm.isAgentProcessing {
                return "typing"
            } else if let lastMsg = conversation.sortedMessages.last {
                return lastMsg.id
            }
            return nil
        }()
        guard let target else { return }

        if animated {
            withAnimation(.easeOut(duration: 0.15)) {
                proxy.scrollTo(target, anchor: .bottom)
            }
        } else {
            withTransaction(Transaction(animation: nil)) {
                proxy.scrollTo(target, anchor: .bottom)
            }
        }
    }
}
