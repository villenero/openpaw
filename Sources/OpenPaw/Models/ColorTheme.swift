import SwiftUI

enum ColorTheme: String, CaseIterable, Identifiable {
    case default_ = "default"
    case sky
    case turquoise
    case teal
    case matcha
    case sunshine
    case peach
    case lilac
    case ebony
    case navy
    case gray
    case dark

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .default_: "Default"
        case .sky: "Sky"
        case .turquoise: "Turquoise"
        case .teal: "Teal"
        case .matcha: "Matcha"
        case .sunshine: "Sunshine"
        case .peach: "Peach"
        case .lilac: "Lilac"
        case .ebony: "Ebony"
        case .navy: "Navy"
        case .gray: "Gray"
        case .dark: "Dark"
        }
    }

    var gradientColors: [Color] {
        switch self {
        case .default_: [Color(hex: "#0A84FF") ?? .blue, Color(hex: "#5AC8FA") ?? .cyan]
        case .sky: [Color(hex: "#4A90D9") ?? .blue, Color(hex: "#74B9FF") ?? .cyan]
        case .turquoise: [Color(hex: "#2ECC71") ?? .green, Color(hex: "#00B894") ?? .mint]
        case .teal: [Color(hex: "#00CEC9") ?? .teal, Color(hex: "#81ECEC") ?? .cyan]
        case .matcha: [Color(hex: "#A8B820") ?? .green, Color(hex: "#BADC58") ?? .yellow]
        case .sunshine: [Color(hex: "#F9CA24") ?? .yellow, Color(hex: "#FDCB6E") ?? .orange]
        case .peach: [Color(hex: "#FD79A8") ?? .pink, Color(hex: "#FDCB6E") ?? .orange]
        case .lilac: [Color(hex: "#A29BFE") ?? .purple, Color(hex: "#DFE6E9") ?? .gray]
        case .ebony: [Color(hex: "#B8860B") ?? .brown, Color(hex: "#D4A574") ?? .orange]
        case .navy: [Color(hex: "#2C3E6B") ?? .indigo, Color(hex: "#4A6FA5") ?? .blue]
        case .gray: [Color(hex: "#636E72") ?? .gray, Color(hex: "#B2BEC3") ?? .secondary]
        case .dark: [Color(hex: "#1A1A2E") ?? .black, Color(hex: "#16213E") ?? .indigo]
        }
    }

    var userBubbleHex: String {
        switch self {
        case .default_: "#0A84FF26"
        case .sky: "#4A90D926"
        case .turquoise: "#2ECC7126"
        case .teal: "#00CEC926"
        case .matcha: "#A8B82026"
        case .sunshine: "#F9CA2426"
        case .peach: "#FD79A826"
        case .lilac: "#A29BFE26"
        case .ebony: "#B8860B26"
        case .navy: "#2C3E6B26"
        case .gray: "#636E7226"
        case .dark: "#2D2D4426"
        }
    }
}
