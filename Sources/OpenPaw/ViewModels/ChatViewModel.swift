import SwiftUI
import SwiftData

@Observable
@MainActor
final class ChatViewModel {
    var streamingContent: String = ""
    var streamingMedia: [MediaItem] = []
    var isStreaming: Bool = false
    var isAgentProcessing: Bool = false
    var error: String?

    // Typewriter state
    private var targetText: String = ""
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
        isAgentProcessing = true
        streamingContent = ""
        streamingMedia = []
        targetText = ""
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
                revealText(parsed.text)
            }

        case "final":
            isAgentProcessing = false
            if let message = payload["message"]?.dictValue {
                let parsed = extractContent(from: message)
                streamingMedia = parsed.media
                // Cancel typewriter and show final text immediately
                typewriterTask?.cancel()
                typewriterTask = nil
                streamingContent = parsed.text
                targetText = parsed.text
            }
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

    // MARK: - Typewriter Effect

    private func revealText(_ newText: String) {
        targetText = newText

        // How many new chars beyond what's already displayed
        let newChars = newText.count - streamingContent.count

        // If new delta arrived while typewriter is running, cancel it and jump to current target
        // then start revealing from there
        if let task = typewriterTask {
            task.cancel()
            typewriterTask = nil
            // Jump to current state minus new chars, so we only reveal truly new content
            streamingContent = String(newText.prefix(newText.count - max(newChars, 0)))
        }

        // Small delta (<20 chars): show immediately
        if newChars < 20 {
            streamingContent = newText
            return
        }

        // Reveal new characters in chunks
        let chunkSize = 8
        let delayNs: UInt64 = 15_000_000 // 15ms

        typewriterTask = Task { [weak self] in
            guard let self else { return }
            let startIndex = self.streamingContent.count

            var pos = startIndex
            while pos < newText.count {
                if Task.isCancelled { return }
                let end = min(pos + chunkSize, newText.count)
                self.streamingContent = String(newText.prefix(end))
                pos = end
                if pos < newText.count {
                    try? await Task.sleep(nanoseconds: delayNs)
                }
            }
            self.typewriterTask = nil
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
                // Same media extraction for loosely-typed arrays
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
        if !targetText.isEmpty {
            streamingContent = targetText
        }

        let hasContent = !streamingContent.isEmpty || !streamingMedia.isEmpty
        if let conversation, hasContent {
            let assistantMsg = Message(role: "assistant", content: streamingContent, media: streamingMedia)
            assistantMsg.conversation = conversation
            conversation.messages.append(assistantMsg)
            conversation.updatedAt = .now

            // Auto-title
            if conversation.title == "New Chat" && !streamingContent.isEmpty {
                let preview = streamingContent.prefix(60)
                let end = preview.lastIndex(of: " ") ?? preview.endIndex
                conversation.title = String(preview[preview.startIndex..<end])
                if preview.count >= 60 { conversation.title += "…" }
            }

            try? modelContext.save()
        }

        isStreaming = false
        isAgentProcessing = false
        streamingContent = ""
        streamingMedia = []
        targetText = ""
        gateway.clearEventHandlers()
    }
}
