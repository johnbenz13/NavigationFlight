import SwiftUI

enum PendingAmendmentPalette {
    static let secondary = adaptive(light: 0x535963, dark: 0xD5DBE3)
    static let destructive = adaptive(light: 0xA82222, dark: 0xFF9C9C)
    static let destructiveBackground = adaptive(light: 0xFCECEC, dark: 0x432323)
    static let quietAction = adaptive(light: 0x0069C6, dark: 0x86C5FF)
    static let quietBackground = adaptive(light: 0xEDF4FC, dark: 0x14283D)
    static let primaryBackground = Color(uiColor: color(0x0069C6))

    private static func adaptive(light: UInt32, dark: UInt32) -> Color {
        Color(uiColor: UIColor { traits in
            color(traits.userInterfaceStyle == .dark ? dark : light)
        })
    }

    private nonisolated static func color(_ hex: UInt32) -> UIColor {
        UIColor(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}
