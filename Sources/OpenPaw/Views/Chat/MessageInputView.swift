import SwiftUI
import UniformTypeIdentifiers

struct MessageInputView: View {
    let isStreaming: Bool
    let isConnected: Bool
    let onSend: (String) -> Void
    let onStop: () -> Void

    @AppStorage("enterSendsMessage") private var enterSendsMessage: Bool = true
    @State private var inputText: String = ""
    @FocusState private var isFocused: Bool
    @State private var showAttachMenu: Bool = false

    // Emoji picker state
    @State private var emojiQuery: String = ""
    @State private var emojiResults: [EmojiEntry] = []
    @State private var emojiSelectedIndex: Int = 0
    @State private var showEmojiPicker: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topLeading) {
                TextEditor(text: $inputText)
                    .font(.body)
                    .focused($isFocused)
                    .frame(minHeight: 36, maxHeight: 120)
                    .fixedSize(horizontal: false, vertical: true)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .onChange(of: inputText) {
                        updateEmojiPicker()
                    }
                    .onKeyPress(.return, phases: .down) { press in
                        if showEmojiPicker && !emojiResults.isEmpty {
                            insertEmoji(emojiResults[emojiSelectedIndex])
                            return .handled
                        }
                        if enterSendsMessage && press.modifiers.isEmpty {
                            sendMessage()
                            return .handled
                        }
                        return .ignored
                    }
                    .onKeyPress(.upArrow, phases: .down) { _ in
                        if showEmojiPicker {
                            emojiSelectedIndex = max(0, emojiSelectedIndex - 1)
                            return .handled
                        }
                        return .ignored
                    }
                    .onKeyPress(.downArrow, phases: .down) { _ in
                        if showEmojiPicker {
                            emojiSelectedIndex = min(emojiResults.count - 1, emojiSelectedIndex + 1)
                            return .handled
                        }
                        return .ignored
                    }
                    .onKeyPress(.escape, phases: .down) { _ in
                        if showEmojiPicker {
                            showEmojiPicker = false
                            return .handled
                        }
                        return .ignored
                    }
                    .onKeyPress(.tab, phases: .down) { _ in
                        if showEmojiPicker && !emojiResults.isEmpty {
                            insertEmoji(emojiResults[emojiSelectedIndex])
                            return .handled
                        }
                        return .ignored
                    }

                // Emoji picker popover positioned above the input
                if showEmojiPicker && !emojiResults.isEmpty {
                    VStack {
                        Spacer()
                        EmojiPickerView(
                            results: emojiResults,
                            selectedIndex: emojiSelectedIndex,
                            onSelect: { entry in insertEmoji(entry) }
                        )
                    }
                    .offset(y: -8)
                    .frame(height: 0, alignment: .bottom)
                    .zIndex(10)
                }
            }
            .zIndex(10)

            HStack {
                Button {
                    showAttachMenu.toggle()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .help("Add attachment")
                .popover(isPresented: $showAttachMenu, arrowEdge: .top) {
                    VStack(alignment: .leading, spacing: 0) {
                        Button {
                            showAttachMenu = false
                            pickImage()
                        } label: {
                            Label("Image", systemImage: "photo")
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)

                        Divider()

                        Button {
                            showAttachMenu = false
                            pickFile()
                        } label: {
                            Label("File", systemImage: "doc")
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)

                        Divider()

                        Button {
                            showAttachMenu = false
                            pasteFromClipboard()
                        } label: {
                            Label("Paste from clipboard", systemImage: "clipboard")
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                    }
                    .frame(width: 200)
                    .padding(.vertical, 4)
                }

                Spacer()

                if isStreaming {
                    Button(action: onStop) {
                        Image(systemName: "stop.fill")
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .help("Stop generating")
                } else {
                    Button(action: sendMessage) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.borderless)
                    .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !isConnected)
                    .keyboardShortcut(.return, modifiers: .command)
                    .help(isConnected ? "Send message" : "Not connected")
                }
            }
            .padding(.top, 4)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.windowBackgroundColor).opacity(0.95))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.primary.opacity(0.2), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.15), radius: 8, y: 2)
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
        .onAppear { isFocused = true }
    }

    private func sendMessage() {
        let text = inputText
        inputText = ""
        showEmojiPicker = false
        onSend(text)
    }

    // MARK: - Emoji Picker Logic

    private func updateEmojiPicker() {
        // Find the last ':' that could be an emoji trigger
        guard let colonRange = findEmojiTrigger(in: inputText) else {
            showEmojiPicker = false
            emojiResults = []
            return
        }

        let query = String(inputText[colonRange])
        emojiQuery = query

        if query.count < 2 {
            showEmojiPicker = false
            emojiResults = []
            return
        }

        let results = EmojiDictionary.search(query, limit: 8)
        emojiResults = results
        emojiSelectedIndex = 0
        showEmojiPicker = !results.isEmpty
    }

    /// Find text after the last unmatched ':' (only if it looks like an emoji query)
    private func findEmojiTrigger(in text: String) -> Range<String.Index>? {
        // Search backwards for ':'
        guard let colonIndex = text.lastIndex(of: ":") else { return nil }

        // Skip if part of a URL (http:// or https://)
        if colonIndex != text.startIndex {
            let prefix = text[text.startIndex...colonIndex]
            if prefix.hasSuffix("http:") || prefix.hasSuffix("https:") {
                return nil
            }
        }

        // Skip if preceded by another ':' (avoid ::, or mid-query like :foo:bar)
        if colonIndex != text.startIndex {
            let before = text.index(before: colonIndex)
            if text[before] == ":" {
                return nil
            }
        }

        let afterColon = text.index(after: colonIndex)
        guard afterColon < text.endIndex else { return nil }

        // The query is everything after ':'
        let query = text[afterColon...]

        // Must only contain valid shortcode chars (letters, digits, underscore)
        if query.contains(where: { !$0.isLetter && !$0.isNumber && $0 != "_" }) {
            return nil
        }

        return afterColon..<text.endIndex
    }

    private func insertEmoji(_ entry: EmojiEntry) {
        // Replace ':query' with the emoji
        guard let colonIndex = inputText.lastIndex(of: ":") else { return }
        inputText.replaceSubrange(colonIndex..<inputText.endIndex, with: entry.emoji)
        showEmojiPicker = false
        emojiResults = []
    }

    // MARK: - Attachments

    private func pickImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.begin { response in
            guard response == .OK else { return }
            // TODO: handle selected image files
            _ = panel.urls
        }
    }

    private func pickFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.begin { response in
            guard response == .OK else { return }
            // TODO: handle selected files
            _ = panel.urls
        }
    }

    private func pasteFromClipboard() {
        // TODO: read image/file from pasteboard
        guard let image = NSPasteboard.general.readObjects(forClasses: [NSImage.self], options: nil)?.first as? NSImage else { return }
        _ = image
    }
}
