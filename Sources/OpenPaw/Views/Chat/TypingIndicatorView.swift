import SwiftUI

struct TypingIndicatorView: View {
    @State private var animating = false
    @AppStorage("colorTheme") private var colorTheme: String = ColorTheme.default_.rawValue

    private var themeAccent: Color {
        let t = ColorTheme.current(from: colorTheme)
        return Color(hex: t.accentHex) ?? .blue
    }

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(themeAccent)
                    .frame(width: 8, height: 8)
                    .offset(y: animating ? -6 : 0)
                    .animation(
                        .easeInOut(duration: 0.4)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.15),
                        value: animating
                    )
            }
        }
        .onAppear { animating = true }
    }
}
