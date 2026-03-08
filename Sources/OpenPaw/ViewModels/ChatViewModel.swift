import SwiftUI
import SwiftData

@Observable
@MainActor
final class ChatViewModel {
    var streamingContent: String = ""
    var isStreaming: Bool = false
    var isAgentProcessing: Bool = false
    var error: String?

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
                          let role = dict["role"] as? String,
                          let content = dict["content"] as? String else { continue }

                    let msg = Message(role: role, content: content)
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
        case "delta", "final":
            isAgentProcessing = false
            if let message = payload["message"]?.dictValue {
                streamingContent = extractText(from: message)
            }
            if state == "final" {
                finishStreaming(in: conversation)
            }

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

    private func extractText(from message: [String: Any]) -> String {
        if let contentArray = message["content"] as? [[String: Any]] {
            return contentArray
                .filter { ($0["type"] as? String) == "text" }
                .compactMap { $0["text"] as? String }
                .joined()
        }
        if let contentArray = message["content"] as? [Any] {
            return contentArray.compactMap { item -> String? in
                guard let dict = item as? [String: Any],
                      (dict["type"] as? String) == "text" else { return nil }
                return dict["text"] as? String
            }.joined()
        }
        if let contentString = message["content"] as? String {
            return contentString
        }
        return ""
    }

    private func finishStreaming(in conversation: Conversation?) {
        guard isStreaming else { return }

        if let conversation, !streamingContent.isEmpty {
            let assistantMsg = Message(role: "assistant", content: streamingContent)
            assistantMsg.conversation = conversation
            conversation.messages.append(assistantMsg)
            conversation.updatedAt = .now

            // Auto-title
            if conversation.title == "New Chat" {
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
        gateway.clearEventHandlers()
    }
}
