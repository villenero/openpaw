import SwiftUI

enum ColorTheme: String, CaseIterable, Identifiable {
    case default_ = "default"
    case sky
    case teal
    case matcha
    case peach
    case lilac
    case navy
    case dark

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .default_: "Default"
        case .sky: "Sky"
        case .teal: "Teal"
        case .matcha: "Matcha"
        case .peach: "Peach"
        case .lilac: "Lilac"
        case .navy: "Navy"
        case .dark: "Dark"
        }
    }

    var gradientColors: [Color] {
        switch self {
        case .default_: [Color(hex: "#0A84FF") ?? .blue, Color(hex: "#5AC8FA") ?? .cyan]
        case .sky: [Color(hex: "#4A90D9") ?? .blue, Color(hex: "#74B9FF") ?? .cyan]
        case .teal: [Color(hex: "#00CEC9") ?? .teal, Color(hex: "#81ECEC") ?? .cyan]
        case .matcha: [Color(hex: "#A8B820") ?? .green, Color(hex: "#BADC58") ?? .yellow]
        case .peach: [Color(hex: "#FD79A8") ?? .pink, Color(hex: "#FDCB6E") ?? .orange]
        case .lilac: [Color(hex: "#A29BFE") ?? .purple, Color(hex: "#DFE6E9") ?? .gray]
        case .navy: [Color(hex: "#2C3E6B") ?? .indigo, Color(hex: "#4A6FA5") ?? .blue]
        case .dark: [Color(hex: "#1A1A2E") ?? .black, Color(hex: "#16213E") ?? .indigo]
        }
    }

    var accentHex: String {
        switch self {
        case .default_: "#0A84FF"
        case .sky: "#4A90D9"
        case .teal: "#00CEC9"
        case .matcha: "#A8B820"
        case .peach: "#FD79A8"
        case .lilac: "#A29BFE"
        case .navy: "#2C3E6B"
        case .dark: "#6C63FF"
        }
    }

    static func current(from storage: String) -> ColorTheme {
        ColorTheme(rawValue: storage) ?? .default_
    }

    var userBubbleHex: String {
        switch self {
        case .default_: "#0A84FF26"
        case .sky: "#4A90D926"
        case .teal: "#00CEC926"
        case .matcha: "#A8B82026"
        case .peach: "#FD79A826"
        case .lilac: "#A29BFE26"
        case .navy: "#2C3E6B26"
        case .dark: "#2D2D4426"
        }
    }
}
