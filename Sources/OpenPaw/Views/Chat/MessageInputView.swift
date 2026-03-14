import SwiftUI
import UniformTypeIdentifiers

struct MessageInputView: View {
    let isStreaming: Bool
    let isConnected: Bool
    let onSend: (String, [PendingAttachment]) -> Void
    let onStop: () -> Void
    @Binding var pendingEditText: String

    @AppStorage("enterSendsMessage") private var enterSendsMessage: Bool = true
    @AppStorage("colorTheme") private var colorTheme: String = ColorTheme.default_.rawValue

    private var themeAccent: Color {
        let t = ColorTheme.current(from: colorTheme)
        return Color(hex: t.accentHex) ?? .blue
    }
    @State private var inputText: String = ""
    @FocusState private var isFocused: Bool
    @State private var showAttachMenu: Bool = false
    @State private var attachments: [PendingAttachment] = []
    @State private var oversizeAlert: Bool = false
    @State private var pasteMonitor: Any?

    // Emoji picker state
    @State private var emojiQuery: String = ""
    @State private var emojiResults: [EmojiEntry] = []
    @State private var emojiSelectedIndex: Int = 0
    @State private var showEmojiPicker: Bool = false

    private var canSend: Bool {
        let hasText = !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return (hasText || !attachments.isEmpty) && isConnected
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Attachment preview strip
            if !attachments.isEmpty {
                attachmentStrip
            }

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
                        .focusEffectDisabled()
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)

                        Divider()

                        Button {
                            showAttachMenu = false
                            pickAudio()
                        } label: {
                            Label("Audio", systemImage: "waveform")
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                        .focusEffectDisabled()
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
                        .focusEffectDisabled()
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
                            .foregroundStyle(themeAccent)
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.borderless)
                    .disabled(!canSend)
                    .keyboardShortcut(.return, modifiers: .command)
                    .help(isConnected ? "Send message" : "Not connected")
                }
            }
            .padding(.top, 4)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.windowBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.primary.opacity(0.2), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.15), radius: 8, y: 2)
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
        .onAppear {
            isFocused = true
            installPasteMonitor()
        }
        .onDisappear {
            removePasteMonitor()
        }
        .onChange(of: pendingEditText) {
            if !pendingEditText.isEmpty {
                inputText = pendingEditText
                pendingEditText = ""
                isFocused = true
            }
        }
        .onDrop(of: Self.supportedDropTypes, isTargeted: nil) { providers in
            handleDrop(providers)
            return true
        }
        .alert("File too large", isPresented: $oversizeAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Files must be under 10 MB. The oversized file was not added.")
        }
    }

    // MARK: - Attachment Preview Strip

    private var attachmentStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(attachments) { att in
                    attachmentPreview(att)
                }
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 6)
        }
    }

    @ViewBuilder
    private func attachmentPreview(_ att: PendingAttachment) -> some View {
        if att.isImage {
            imagePreview(att)
        } else {
            audioPreview(att)
        }
    }

    private func imagePreview(_ att: PendingAttachment) -> some View {
        ZStack(alignment: .topTrailing) {
            if let nsImage = NSImage(data: att.data) {
                Image(nsImage: nsImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.secondary.opacity(0.2))
                    .frame(width: 80, height: 80)
                    .overlay {
                        Image(systemName: "photo")
                            .foregroundStyle(.secondary)
                    }
            }
            removeButton(for: att)
        }
    }

    private func audioPreview(_ att: PendingAttachment) -> some View {
        ZStack(alignment: .topTrailing) {
            HStack(spacing: 6) {
                Image(systemName: "waveform")
                    .foregroundStyle(.secondary)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(att.fileName)
                        .font(.caption)
                        .lineLimit(1)
                    Text(formatBytes(att.size))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .padding(.trailing, 16)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.secondary.opacity(0.1))
            )
            removeButton(for: att)
        }
    }

    private func removeButton(for att: PendingAttachment) -> some View {
        Button {
            attachments.removeAll { $0.id == att.id }
        } label: {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 16))
                .foregroundStyle(.white, .secondary)
        }
        .buttonStyle(.plain)
        .offset(x: 4, y: -4)
    }

    // MARK: - Send

    private func sendMessage() {
        let text = inputText
        let atts = attachments
        inputText = ""
        attachments = []
        showEmojiPicker = false
        onSend(text, atts)
    }

    // MARK: - File Pickers

    private static let imageTypes: [UTType] = [.png, .jpeg, .webP, .gif, .heic]
    private static let audioTypes: [UTType] = [.mp3, .mpeg4Audio, .wav, .audio]
    static let supportedDropTypes: [UTType] = imageTypes + audioTypes + [.fileURL]

    private func pickImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = Self.imageTypes
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.begin { response in
            guard response == .OK else { return }
            addFiles(from: panel.urls)
        }
    }

    private func pickAudio() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = Self.audioTypes
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.begin { response in
            guard response == .OK else { return }
            addFiles(from: panel.urls)
        }
    }

    private func pasteFromClipboard() {
        let pb = NSPasteboard.general

        // Try image data — always compress to JPEG to avoid oversized payloads
        // (retina screenshots can be 20-30MB as raw TIFF/uncompressed PNG)
        if let imgData = pb.data(forType: .png),
           let bitmap = NSBitmapImageRep(data: imgData),
           let jpegData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.8]) {
            addAttachment(data: jpegData, mimeType: "image/jpeg", fileName: "Pasted Image.jpg")
            return
        }
        if let imgData = pb.data(forType: .tiff),
           let bitmap = NSBitmapImageRep(data: imgData),
           let jpegData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.8]) {
            addAttachment(data: jpegData, mimeType: "image/jpeg", fileName: "Pasted Image.jpg")
            return
        }

        // Try file URLs
        if let urls = pb.readObjects(forClasses: [NSURL.self], options: [
            .urlReadingContentsConformToTypes: (Self.imageTypes + Self.audioTypes).map(\.identifier)
        ]) as? [URL], !urls.isEmpty {
            addFiles(from: urls)
        }
    }

    // MARK: - Drag & Drop

    private func handleDrop(_ providers: [NSItemProvider]) {
        for provider in providers {
            // Try file URL first
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                    guard let data = item as? Data,
                          let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                    DispatchQueue.main.async {
                        addFiles(from: [url])
                    }
                }
            }
            // Try raw image data
            else if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                provider.loadDataRepresentation(forTypeIdentifier: UTType.png.identifier) { data, _ in
                    guard let data else { return }
                    DispatchQueue.main.async {
                        addAttachment(data: data, mimeType: "image/png", fileName: "Dropped Image.png")
                    }
                }
            }
        }
    }

    // MARK: - Cmd+V Paste Interception

    private func installPasteMonitor() {
        pasteMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [self] event in
            // Cmd+V
            guard event.modifierFlags.contains(.command),
                  event.charactersIgnoringModifiers == "v" else {
                return event
            }

            let pb = NSPasteboard.general
            let hasImage = pb.canReadObject(forClasses: [NSImage.self], options: nil)

            // Only intercept if there's an image and no text (pure image paste)
            let hasText = pb.string(forType: .string) != nil
            if hasImage && !hasText {
                pasteFromClipboard()
                return nil // swallow the event
            }

            return event // let TextEditor handle text paste
        }
    }

    private func removePasteMonitor() {
        if let monitor = pasteMonitor {
            NSEvent.removeMonitor(monitor)
            pasteMonitor = nil
        }
    }

    // MARK: - File Processing

    private func addFiles(from urls: [URL]) {
        for url in urls {
            guard let data = try? Data(contentsOf: url) else { continue }
            let mime = mimeType(for: url)
            addAttachment(data: data, mimeType: mime, fileName: url.lastPathComponent)
        }
    }

    private func addAttachment(data: Data, mimeType: String, fileName: String) {
        let att = PendingAttachment(data: data, mimeType: mimeType, fileName: fileName)
        if att.isOversized {
            oversizeAlert = true
            return
        }
        attachments.append(att)
    }

    private func mimeType(for url: URL) -> String {
        if let utType = UTType(filenameExtension: url.pathExtension) {
            return utType.preferredMIMEType ?? "application/octet-stream"
        }
        return "application/octet-stream"
    }

    private func formatBytes(_ bytes: Int) -> String {
        if bytes < 1024 { return "\(bytes) B" }
        let kb = Double(bytes) / 1024
        if kb < 1024 { return String(format: "%.0f KB", kb) }
        let mb = kb / 1024
        return String(format: "%.1f MB", mb)
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
}
