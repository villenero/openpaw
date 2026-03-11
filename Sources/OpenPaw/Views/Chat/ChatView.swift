import SwiftUI
import SwiftData

struct ChatView: View {
    let conversation: Conversation
    let gateway: GatewayService

    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: ChatViewModel?
    @State private var isAtBottom: Bool = true
    @State private var scrollTrigger: Int = 0
    @State private var inputHeight: CGFloat = 100
    @State private var scrollOffset: CGFloat = 0
    @State private var contentHeight: CGFloat = 0
    @State private var scrollViewHeight: CGFloat = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            messageList

            VStack(spacing: 0) {
                if !isAtBottom {
                    Button {
                        scrollTrigger += 1
                    } label: {
                        Image(systemName: "arrow.down")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.primary)
                            .frame(width: 36, height: 36)
                            .background(
                                Circle()
                                    .fill(Color(.windowBackgroundColor))
                                    .overlay(Circle().stroke(Color.primary.opacity(0.2), lineWidth: 1))
                                    .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
                            )
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, 8)
                    .transition(.opacity.combined(with: .scale(scale: 0.8)))
                }

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
            .frame(minWidth: 400, maxWidth: 800)
            .animation(.easeInOut(duration: 0.2), value: isAtBottom)
            .background(
                GeometryReader { geo in
                    Color.clear.onChange(of: geo.size.height) { _, newH in
                        inputHeight = newH
                    }
                    .onAppear { inputHeight = geo.size.height }
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
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Assistant")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                            TypingIndicatorView()
                                .padding(.horizontal, 4)
                                .padding(.vertical, 10)
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

                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding()
                .padding(.bottom, inputHeight)
                .frame(minWidth: 400, maxWidth: 800)
                .frame(maxWidth: .infinity)
                .background(
                    GeometryReader { geo in
                        Color.clear
                            .onChange(of: geo.frame(in: .named("chatScroll")).minY) { _, newVal in
                                scrollOffset = newVal
                                contentHeight = geo.size.height
                                updateIsAtBottom()
                            }
                            .onChange(of: geo.size.height) { _, newVal in
                                contentHeight = newVal
                                updateIsAtBottom()
                            }
                    }
                )
                .scaleEffect(x: 1, y: -1)
            }
            .scaleEffect(x: 1, y: -1)
            .coordinateSpace(name: "chatScroll")
            .background(
                GeometryReader { geo in
                    Color.clear
                        .onAppear { scrollViewHeight = geo.size.height }
                        .onChange(of: geo.size.height) { _, newH in
                            scrollViewHeight = newH
                            updateIsAtBottom()
                        }
                }
            )
            .onAppear {
                scrollToBottom(proxy: proxy, animated: false)
            }
            .onChange(of: conversation) {
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
            .onChange(of: viewModel?.isAgentProcessing) {
                scrollToBottom(proxy: proxy, animated: true)
            }
            .onChange(of: scrollTrigger) {
                scrollToBottom(proxy: proxy, animated: true)
            }
        }
    }

    private func updateIsAtBottom() {
        // In flipped scroll: scrollOffset is minY of content in scroll coordinate space
        // At bottom (newest messages visible): scrollOffset ≈ 0 or small negative
        // Scrolled up (older messages): scrollOffset becomes more positive
        let threshold: CGFloat = 50
        let atBottom = scrollOffset >= -threshold
        if atBottom != isAtBottom {
            isAtBottom = atBottom
        }
    }

    private func scrollToBottom(proxy: ScrollViewProxy, animated: Bool) {
        if animated {
            withAnimation(.easeOut(duration: 0.15)) {
                proxy.scrollTo("bottom", anchor: .bottom)
            }
        } else {
            withTransaction(Transaction(animation: nil)) {
                proxy.scrollTo("bottom", anchor: .bottom)
            }
        }
    }
}
