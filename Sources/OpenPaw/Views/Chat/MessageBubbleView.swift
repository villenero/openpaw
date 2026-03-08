import SwiftUI

struct MessageBubbleView: View {
    let role: String
    let content: String
    var media: [MediaItem] = []
    var isStreamingFade: Bool = false

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
            return AnyShapeStyle(Color.accentColor.opacity(0.15))
        } else {
            return AnyShapeStyle(Color(.controlBackgroundColor))
        }
    }
}
