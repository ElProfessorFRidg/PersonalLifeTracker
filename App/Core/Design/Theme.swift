// GÉNÉRÉ par scripts/gen_theme.py depuis design/tokens.json : ne pas modifier à la main.
import SwiftUI

enum ThemeMode: String, CaseIterable { case light, dark, amoled }

extension Color {
    init(hex: UInt32) { self.init(red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255) }
}

struct Palette {
    let background: Color
    let surface: Color
    let textPrimary: Color
    let textSecondary: Color
    let accent: Color
    let work: Color
    let study: Color
    let errand: Color
    let danger: Color
}

enum Theme {
    static let light = Palette(
        background: Color(hex: 0xF6F7FB),
        surface: Color(hex: 0xFFFFFF),
        textPrimary: Color(hex: 0x12151C),
        textSecondary: Color(hex: 0x5B6475),
        accent: Color(hex: 0x4F7CFF),
        work: Color(hex: 0x2E9E6B),
        study: Color(hex: 0x8A5CF6),
        errand: Color(hex: 0xE8A317),
        danger: Color(hex: 0xD64545)
    )
    static let dark = Palette(
        background: Color(hex: 0x0E1117),
        surface: Color(hex: 0x171B24),
        textPrimary: Color(hex: 0xF2F4F8),
        textSecondary: Color(hex: 0x9AA3B5),
        accent: Color(hex: 0x6E93FF),
        work: Color(hex: 0x4CC38A),
        study: Color(hex: 0xA98BFF),
        errand: Color(hex: 0xF2BC4A),
        danger: Color(hex: 0xF26B6B)
    )
    static let amoled = Palette(
        background: Color(hex: 0x000000),
        surface: Color(hex: 0x0A0A0A),
        textPrimary: Color(hex: 0xF2F4F8),
        textSecondary: Color(hex: 0x9AA3B5),
        accent: Color(hex: 0x6E93FF),
        work: Color(hex: 0x4CC38A),
        study: Color(hex: 0xA98BFF),
        errand: Color(hex: 0xF2BC4A),
        danger: Color(hex: 0xF26B6B)
    )
    static func palette(_ mode: ThemeMode) -> Palette { switch mode { case .light: return light; case .dark: return dark; case .amoled: return amoled } }
    enum Radius {
        static let small: CGFloat = 8
        static let medium: CGFloat = 14
        static let large: CGFloat = 22
    }
    enum Spacing {
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 16
        static let l: CGFloat = 24
        static let xl: CGFloat = 32
    }
}
