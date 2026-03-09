import SwiftUI
import SwiftData

@Observable
@MainActor
final class ChatViewModel {
    // The UI reads displayedContent (typewriter-buffered) instead of raw gateway text
    var displayedContent: String { String(receivedContent.prefix(displayedCharCount)) }
    var streamingMedia: [MediaItem] = []
    var isStreaming: Bool = false
    var isStreamingFinalized: Bool = false
    var isAgentProcessing: Bool = false
    var error: String?

    // Typewriter buffer state
    private var receivedContent: String = ""
    private var displayedCharCount: Int = 0
    private var typewriterTask: Task<Void, Never>?

    private let gateway: GatewayService
    private let modelContext: ModelContext

    init(gateway: GatewayService, modelContext: ModelContext) {
        self.gateway = gateway
        self.modelContext = modelContext
    }

    func send(text: String, in conversation: Conversation) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard gateway.isConnected else {
            error = "Not connected to server"
            return
        }

        error = nil

        // Add user message
        let userMsg = Message(role: "user", content: trimmed)
        userMsg.conversation = conversation
        conversation.messages.append(userMsg)
        conversation.updatedAt = .now
        try? modelContext.save()

        // Stream response
        isStreaming = true
        isStreamingFinalized = false
        isAgentProcessing = true
        receivedContent = ""
        displayedCharCount = 0
        streamingMedia = []
        typewriterTask?.cancel()
        typewriterTask = nil

        // Listen for chat and agent events
        gateway.clearEventHandlers()
        gateway.onEvent("chat-stream") { [weak self] (frame: IncomingFrame) in
            guard frame.event == "chat" else { return }
            Task { @MainActor in
                self?.handleChatEvent(frame, conversation: conversation)
            }
        }
        gateway.onEvent("agent-lifecycle") { [weak self] (frame: IncomingFrame) in
            guard frame.event == "agent" else { return }
            Task { @MainActor in
                self?.handleAgentEvent(frame)
            }
        }

        Task {
            do {
                let response = try await gateway.sendChatMessage(trimmed)
                if response.ok != true {
                    let msg = response.error?.message ?? "Send failed"
                    self.error = msg
                    self.isStreaming = false
                }
            } catch {
                self.error = error.localizedDescription
                self.isStreaming = false
            }
        }
    }

    func stop() {
        finishStreaming(in: nil)
    }

    func loadHistory(for conversation: Conversation) {
        guard gateway.isConnected else { return }

        Task {
            do {
                let response = try await gateway.getChatHistory()
                guard response.ok == true,
                      let payload = response.payload,
                      let messagesArray = payload["messages"]?.arrayValue else { return }

                // Only load if conversation is empty
                guard conversation.messages.isEmpty else { return }

                for item in messagesArray {
                    guard let dict = item as? [String: Any],
                          let role = dict["role"] as? String else { continue }

                    let parsed = extractContent(from: dict)
                    let msg = Message(role: role, content: parsed.text, media: parsed.media)
                    msg.conversation = conversation
                    conversation.messages.append(msg)
                }
                try? modelContext.save()
            } catch {
                // History load is best-effort
            }
        }
    }

    private func handleChatEvent(_ frame: IncomingFrame, conversation: Conversation) {
        guard let payload = frame.payload else { return }

        let state = payload["state"]?.stringValue

        switch state {
        case "delta":
            isAgentProcessing = false
            if let message = payload["message"]?.dictValue {
                let parsed = extractContent(from: message)
                streamingMedia = parsed.media
                receivedContent = parsed.text
                startTypewriterIfNeeded()
            }

        case "final":
            isAgentProcessing = false
            if let message = payload["message"]?.dictValue {
                let parsed = extractContent(from: message)
                streamingMedia = parsed.media
                receivedContent = parsed.text
            }
            // Cancel typewriter, show all text immediately
            typewriterTask?.cancel()
            typewriterTask = nil
            displayedCharCount = receivedContent.count
            isStreamingFinalized = true
            finishStreaming(in: conversation)

        case "aborted":
            finishStreaming(in: conversation)

        case "error":
            let errMsg = payload["errorMessage"]?.stringValue ?? "Agent error"
            error = errMsg
            finishStreaming(in: conversation)

        default:
            break
        }
    }

    private func handleAgentEvent(_ frame: IncomingFrame) {
        guard let payload = frame.payload,
              payload["stream"]?.stringValue == "lifecycle",
              let data = payload["data"]?.dictValue else { return }

        let phase = data["phase"] as? String
        if phase == "start" {
            isAgentProcessing = true
        } else if phase == "end" || phase == "error" {
            isAgentProcessing = false
        }
    }

    // MARK: - Typewriter Buffer

    private func startTypewriterIfNeeded() {
        guard typewriterTask == nil else { return } // already running

        typewriterTask = Task { [weak self] in
            while let self, !Task.isCancelled {
                let target = self.receivedContent.count
                guard self.displayedCharCount < target else {
                    // Caught up — wait for more content
                    self.typewriterTask = nil
                    return
                }

                let buffered = target - self.displayedCharCount
                let delayMs: UInt64
                let step: Int

                // Speed is king: large buffers flush almost instantly,
                // only small buffers get the cosmetic typewriter pacing.
                if buffered > 200 {
                    // Dump everything except the fade window (20 chars) in one go
                    self.displayedCharCount = target - 20
                    continue
                } else if buffered > 80 {
                    delayMs = 1
                    step = buffered / 4  // flush in ~4 ticks
                } else if buffered > 30 {
                    delayMs = 2
                    step = 3
                } else if buffered > 10 {
                    delayMs = 8
                    step = 1
                } else {
                    delayMs = 15
                    step = 1
                }

                self.displayedCharCount = min(self.displayedCharCount + step, target)
                try? await Task.sleep(nanoseconds: delayMs * 1_000_000)
            }
        }
    }

    private func extractContent(from message: [String: Any]) -> ParsedContent {
        var result = ParsedContent()

        if let contentArray = message["content"] as? [[String: Any]] {
            for part in contentArray {
                let type = part["type"] as? String
                switch type {
                case "text":
                    if let text = part["text"] as? String {
                        result.text += text
                    }
                case "image":
                    if let source = part["source"] as? [String: Any],
                       (source["type"] as? String) == "base64",
                       let mediaType = source["media_type"] as? String,
                       let dataStr = source["data"] as? String,
                       let data = Data(base64Encoded: dataStr) {
                        result.media.append(.imageBase64(data: data, mediaType: mediaType))
                    } else if let source = part["source"] as? [String: Any],
                              (source["type"] as? String) == "url",
                              let urlStr = source["url"] as? String,
                              let url = URL(string: urlStr) {
                        let alt = part["alt"] as? String ?? ""
                        result.media.append(.imageURL(url: url, alt: alt))
                    }
                case "audio":
                    if let source = part["source"] as? [String: Any],
                       (source["type"] as? String) == "base64",
                       let mediaType = source["media_type"] as? String,
                       let dataStr = source["data"] as? String,
                       let data = Data(base64Encoded: dataStr) {
                        result.media.append(.audioBase64(data: data, mediaType: mediaType))
                    } else if let source = part["source"] as? [String: Any],
                              (source["type"] as? String) == "url",
                              let urlStr = source["url"] as? String,
                              let url = URL(string: urlStr) {
                        result.media.append(.audioURL(url: url))
                    }
                default:
                    break
                }
            }
            return result
        }

        if let contentArray = message["content"] as? [Any] {
            for item in contentArray {
                guard let dict = item as? [String: Any] else { continue }
                let type = dict["type"] as? String
                if type == "text", let text = dict["text"] as? String {
                    result.text += text
                }
                if type == "image", let source = dict["source"] as? [String: Any] {
                    if (source["type"] as? String) == "base64",
                       let mediaType = source["media_type"] as? String,
                       let dataStr = source["data"] as? String,
                       let data = Data(base64Encoded: dataStr) {
                        result.media.append(.imageBase64(data: data, mediaType: mediaType))
                    }
                }
            }
            return result
        }

        if let contentString = message["content"] as? String {
            result.text = contentString
        }

        return result
    }

    private func finishStreaming(in conversation: Conversation?) {
        guard isStreaming else { return }

        // Cancel typewriter and show final text
        typewriterTask?.cancel()
        typewriterTask = nil
        displayedCharCount = receivedContent.count

        let finalText = receivedContent
        let hasContent = !finalText.isEmpty || !streamingMedia.isEmpty
        if let conversation, hasContent {
            let assistantMsg = Message(role: "assistant", content: finalText, media: streamingMedia)
            assistantMsg.conversation = conversation
            conversation.messages.append(assistantMsg)
            conversation.updatedAt = .now

            // Auto-title
            if conversation.title == "New Chat" && !finalText.isEmpty {
                let preview = finalText.prefix(60)
                let end = preview.lastIndex(of: " ") ?? preview.endIndex
                conversation.title = String(preview[preview.startIndex..<end])
                if preview.count >= 60 { conversation.title += "…" }
            }

            try? modelContext.save()
        }

        isStreaming = false
        isAgentProcessing = false
        receivedContent = ""
        displayedCharCount = 0
        streamingMedia = []
        gateway.clearEventHandlers()
    }
}
