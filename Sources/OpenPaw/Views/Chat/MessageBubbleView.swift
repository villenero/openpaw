import SwiftUI

enum BubbleColors {
    static let defaultUserHex = "#0A84FF26"     // accentColor 15% opacity
    static let defaultAssistantHex = "#8080801A" // controlBackground-like

    static var defaultUser: Color { Color(hex: defaultUserHex) ?? .blue.opacity(0.15) }
    static var defaultAssistant: Color { Color(hex: defaultAssistantHex) ?? Color(.controlBackgroundColor) }
}

extension Color {
    init?(hex: String) {
        var h = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if h.hasPrefix("#") { h = String(h.dropFirst()) }
        guard h.count == 6 || h.count == 8 else { return nil }
        var value: UInt64 = 0
        guard Scanner(string: h).scanHexInt64(&value) else { return nil }
        if h.count == 8 {
            let r = Double((value >> 24) & 0xFF) / 255
            let g = Double((value >> 16) & 0xFF) / 255
            let b = Double((value >> 8) & 0xFF) / 255
            let a = Double(value & 0xFF) / 255
            self.init(red: r, green: g, blue: b, opacity: a)
        } else {
            let r = Double((value >> 16) & 0xFF) / 255
            let g = Double((value >> 8) & 0xFF) / 255
            let b = Double(value & 0xFF) / 255
            self.init(red: r, green: g, blue: b)
        }
    }

    func toHex() -> String {
        guard let c = NSColor(self).usingColorSpace(.sRGB) else { return "#000000" }
        let r = Int(c.redComponent * 255)
        let g = Int(c.greenComponent * 255)
        let b = Int(c.blueComponent * 255)
        let a = Int(c.alphaComponent * 255)
        if a < 255 {
            return String(format: "#%02X%02X%02X%02X", r, g, b, a)
        }
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}

struct MessageBubbleView: View {
    let role: String
    let content: String
    var media: [MediaItem] = []
    var isStreamingFade: Bool = false

    @AppStorage("userBubbleColor") private var userBubbleHex: String = BubbleColors.defaultUserHex
    @AppStorage("assistantBubbleColor") private var assistantBubbleHex: String = BubbleColors.defaultAssistantHex

    private var isUser: Bool { role == "user" }

    var body: some View {
        HStack {
            if isUser { Spacer(minLength: 60) }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                Text(isUser ? "You" : "Assistant")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

                VStack(alignment: .leading, spacing: 8) {
                    // Media before text
                    if !media.isEmpty {
                        MediaContentView(media: media)
                    }

                    // Text content
                    if !content.isEmpty {
                        if isUser {
                            Text(markdownContent)
                                .textSelection(.enabled)
                        } else if isStreamingFade {
                            TypewriterTextView(text: content)
                        } else {
                            MarkdownView(source: content)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(bubbleBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .hoverCopyButton(text: content)
            }

            if !isUser { Spacer(minLength: 60) }
        }
    }

    private var markdownContent: AttributedString {
        (try? AttributedString(
            markdown: content,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        )) ?? AttributedString(content)
    }

    private var bubbleBackground: some ShapeStyle {
        if isUser {
            return AnyShapeStyle(Color(hex: userBubbleHex) ?? BubbleColors.defaultUser)
        } else {
            return AnyShapeStyle(Color(hex: assistantBubbleHex) ?? BubbleColors.defaultAssistant)
        }
    }
}
