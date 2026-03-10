import SwiftUI

enum BubbleColors {
    static let defaultUserHex = "#0A84FF26"     // accentColor 15% opacity
    static var defaultUser: Color { Color(hex: defaultUserHex) ?? .blue.opacity(0.15) }
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

    private var isUser: Bool { role == "user" }

    var body: some View {
        if isUser {
            userBubble
        } else {
            assistantBlock
        }
    }

    private var userBubble: some View {
        HStack {
            Spacer(minLength: 80)

            VStack(alignment: .trailing, spacing: 4) {
                Text("You")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

                VStack(alignment: .leading, spacing: 8) {
                    if !media.isEmpty {
                        MediaContentView(media: media)
                    }
                    if !content.isEmpty {
                        Text(markdownContent)
                            .textSelection(.enabled)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(hex: userBubbleHex) ?? BubbleColors.defaultUser)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .hoverCopyButton(text: content)
            }
        }
    }

    private var assistantBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Assistant")
                .font(.caption2)
                .foregroundStyle(.tertiary)

            VStack(alignment: .leading, spacing: 8) {
                if !media.isEmpty {
                    MediaContentView(media: media)
                }
                if !content.isEmpty {
                    if isStreamingFade {
                        TypewriterTextView(text: content)
                    } else {
                        MarkdownView(source: content)
                    }
                }
            }
            .hoverCopyButton(text: content)
        }
    }

    private var markdownContent: AttributedString {
        (try? AttributedString(
            markdown: content,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        )) ?? AttributedString(content)
    }

}
