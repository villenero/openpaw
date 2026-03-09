import SwiftUI

/// Renders streaming text with a trailing alpha gradient.
/// The newest character has 0% opacity, each preceding character gains
/// progressively more opacity until reaching 100% after `fadeWindow` characters.
struct TypewriterTextView: View {
    let text: String

    private static let fadeWindow = 20

    var body: some View {
        Text(attributedText)
    }

    private var attributedText: AttributedString {
        var attributed = (try? AttributedString(
            markdown: text,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        )) ?? AttributedString(text)

        let totalChars = attributed.characters.count
        let fadeChars = min(Self.fadeWindow, totalChars)

        guard fadeChars > 0 else { return attributed }

        // i=0 → newest char (alpha ≈ 0), i=fadeWindow-1 → oldest in window (alpha ≈ 1)
        for i in 0..<fadeChars {
            let alpha = Double(i) / Double(Self.fadeWindow)
            let offset = -(i + 1)
            let charIndex = attributed.index(attributed.endIndex, offsetByCharacters: offset)
            let nextIndex = attributed.index(charIndex, offsetByCharacters: 1)
            attributed[charIndex..<nextIndex].foregroundColor = NSColor.labelColor.withAlphaComponent(alpha)
        }

        return attributed
    }
}
