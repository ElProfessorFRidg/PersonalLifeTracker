// GÉNÉRÉ par scripts/gen_theme.py depuis design/tokens.json : ne pas modifier à la main.
import SwiftUI

enum ThemeMode: String, CaseIterable { case light, dark, amoled }

extension Color {
    init(hex: UInt32) { self.init(red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255) }
}

struct Palette {
    let background: Color
    let surface: Color
    let surfaceRaised: Color
    let fill: Color
    let separator: Color
    let textPrimary: Color
    let textSecondary: Color
    let textTertiary: Color
    let accent: Color
    let accentOn: Color
    let accentSoft: Color
    let work: Color
    let workSoft: Color
    let study: Color
    let studySoft: Color
    let errand: Color
    let errandSoft: Color
    let danger: Color
    let dangerOn: Color
    let dangerSoft: Color
    let warning: Color
    let warningSoft: Color
    let success: Color
}

enum Theme {
    static let light = Palette(
        background: Color(hex: 0xEDF0F5),
        surface: Color(hex: 0xFFFFFF),
        surfaceRaised: Color(hex: 0xF5F7FA),
        fill: Color(hex: 0xE0E5EE),
        separator: Color(hex: 0xD3D9E4),
        textPrimary: Color(hex: 0x101726),
        textSecondary: Color(hex: 0x4A566C),
        textTertiary: Color(hex: 0x5F6A7F),
        accent: Color(hex: 0x2447B8),
        accentOn: Color(hex: 0xFFFFFF),
        accentSoft: Color(hex: 0xDCE4FA),
        work: Color(hex: 0x146B45),
        workSoft: Color(hex: 0xD8EEE2),
        study: Color(hex: 0x962A70),
        studySoft: Color(hex: 0xF5DEEB),
        errand: Color(hex: 0x755400),
        errandSoft: Color(hex: 0xF5E9C8),
        danger: Color(hex: 0xB82828),
        dangerOn: Color(hex: 0xFFFFFF),
        dangerSoft: Color(hex: 0xF9DEDC),
        warning: Color(hex: 0x99440A),
        warningSoft: Color(hex: 0xFAE0CC),
        success: Color(hex: 0x146B45)
    )
    static let dark = Palette(
        background: Color(hex: 0x0E131D),
        surface: Color(hex: 0x182030),
        surfaceRaised: Color(hex: 0x212B3E),
        fill: Color(hex: 0x2A3449),
        separator: Color(hex: 0x2E384C),
        textPrimary: Color(hex: 0xEEF2FA),
        textSecondary: Color(hex: 0xA9B4C9),
        textTertiary: Color(hex: 0x909CB4),
        accent: Color(hex: 0x93ABFF),
        accentOn: Color(hex: 0x0A1230),
        accentSoft: Color(hex: 0x22305C),
        work: Color(hex: 0x5FCD96),
        workSoft: Color(hex: 0x173B2C),
        study: Color(hex: 0xF09ACF),
        studySoft: Color(hex: 0x47223D),
        errand: Color(hex: 0xEDBA52),
        errandSoft: Color(hex: 0x41310F),
        danger: Color(hex: 0xFF8A81),
        dangerOn: Color(hex: 0x3A0B08),
        dangerSoft: Color(hex: 0x4C201E),
        warning: Color(hex: 0xFFA465),
        warningSoft: Color(hex: 0x48290F),
        success: Color(hex: 0x5FCD96)
    )
    static let amoled = Palette(
        background: Color(hex: 0x000000),
        surface: Color(hex: 0x0C0F15),
        surfaceRaised: Color(hex: 0x151A23),
        fill: Color(hex: 0x1C222D),
        separator: Color(hex: 0x1F2631),
        textPrimary: Color(hex: 0xEEF2FA),
        textSecondary: Color(hex: 0xA3AEC4),
        textTertiary: Color(hex: 0x8490A8),
        accent: Color(hex: 0x93ABFF),
        accentOn: Color(hex: 0x0A1230),
        accentSoft: Color(hex: 0x141D3D),
        work: Color(hex: 0x5FCD96),
        workSoft: Color(hex: 0x0F2A1F),
        study: Color(hex: 0xF09ACF),
        studySoft: Color(hex: 0x30162A),
        errand: Color(hex: 0xEDBA52),
        errandSoft: Color(hex: 0x2C2109),
        danger: Color(hex: 0xFF8A81),
        dangerOn: Color(hex: 0x3A0B08),
        dangerSoft: Color(hex: 0x341514),
        warning: Color(hex: 0xFFA465),
        warningSoft: Color(hex: 0x301A09),
        success: Color(hex: 0x5FCD96)
    )
    static func palette(_ mode: ThemeMode) -> Palette { switch mode { case .light: return light; case .dark: return dark; case .amoled: return amoled } }
    enum Radius {
        static let small: CGFloat = 8
        static let medium: CGFloat = 14
        static let large: CGFloat = 22
        static let sheet: CGFloat = 28
        static let pill: CGFloat = 999
    }
    enum Spacing {
        static let xxs: CGFloat = 2
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 16
        static let l: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
    }
}
