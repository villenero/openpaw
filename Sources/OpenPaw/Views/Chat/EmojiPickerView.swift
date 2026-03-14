import SwiftUI

struct EmojiPickerView: View {
    let results: [EmojiEntry]
    let selectedIndex: Int
    let onSelect: (EmojiEntry) -> Void
    @AppStorage("colorTheme") private var colorTheme: String = ColorTheme.default_.rawValue

    private var themeAccent: Color {
        let t = ColorTheme.current(from: colorTheme)
        return Color(hex: t.accentHex) ?? .blue
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(results.enumerated()), id: \.element.emoji) { index, entry in
                Button(action: { onSelect(entry) }) {
                    HStack(spacing: 8) {
                        Text(entry.emoji)
                            .font(.title2)
                        Text(entry.keywords.first ?? "")
                            .font(.body)
                            .foregroundStyle(.primary)
                        Spacer()
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(index == selectedIndex ? themeAccent.opacity(0.2) : Color.clear)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
        .frame(width: 260)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(color: .black.opacity(0.15), radius: 8, y: 2)
    }
}
