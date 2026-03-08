import SwiftUI

/// Renders streaming text with an alpha fade-in on the trailing 6 characters.
/// Uses a single AttributedString for proper line wrapping.
struct TypewriterTextView: View {
    let text: String

    private static let fadeCount = 6
    private static let alphaValues: [Double] = [0.92, 0.80, 0.65, 0.45, 0.30, 0.15]

    var body: some View {
        Text(attributedText)
            .textSelection(.enabled)
    }

    private var attributedText: AttributedString {
        // Try to parse inline markdown first
        var attributed = (try? AttributedString(
            markdown: text,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        )) ?? AttributedString(text)

        let totalChars = attributed.characters.count
        let fadeChars = min(Self.fadeCount, totalChars)

        guard fadeChars > 0 else { return attributed }

        // Apply fading opacity to the last N characters
        for i in 0..<fadeChars {
            let offset = -(i + 1)
            let charIndex = attributed.index(attributed.endIndex, offsetByCharacters: offset)
            let nextIndex = attributed.index(charIndex, offsetByCharacters: 1)
            let alpha = Self.alphaValues[i]
            attributed[charIndex..<nextIndex].foregroundColor = NSColor.labelColor.withAlphaComponent(alpha)
        }

        return attributed
    }
}
