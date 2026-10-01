import SwiftUI

/// App colors by role. Screens use these (`Theme.accent`, `Theme.background`),
/// never raw hex values, so a color changes in one place. Values and usage
/// rules come from docs/BRAND.md.
enum Theme {
    /// Buttons, toggles, links.
    static let accent = Palette.teal
    static let accentSecondary = Palette.purple
    /// Small highlights, e.g. a savings figure.
    static let highlight = Palette.mint
    static let background = Palette.deepNavy
    static let text = Palette.offWhite

    /// Mint → Teal → Cyan → Blue → Violet, top-left to bottom-right. For hero
    /// elements only (the savings card, the app icon), not every surface.
    static let gradient = LinearGradient(
        colors: [Palette.mint, Palette.teal, Palette.cyan, Palette.blue, Palette.violet],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// The raw brand palette. Prefer the roles above; reach for these only for
    /// gradients or one-off art. Violet and Purple are low-contrast on the
    /// background, so keep them off small text.
    enum Palette {
        static let mint = Color(hex: 0x50F0C0)
        static let teal = Color(hex: 0x20E0D0)
        static let cyan = Color(hex: 0x10D0F0)
        static let blue = Color(hex: 0x3090F0)
        static let violet = Color(hex: 0x7040F0)
        static let purple = Color(hex: 0x9050F0)
        static let deepNavy = Color(hex: 0x050B18)
        static let offWhite = Color(hex: 0xF5F7FA)
    }
}

extension Color {
    /// A color from a 24-bit RGB hex value, e.g. `Color(hex: 0x20E0D0)`.
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

#Preview("Theme") {
    VStack(alignment: .leading, spacing: 12) {
        RoundedRectangle(cornerRadius: 20)
            .fill(Theme.gradient)
            .frame(height: 120)
        ForEach([
            ("Accent", Theme.accent), ("Secondary accent", Theme.accentSecondary),
            ("Highlight", Theme.highlight), ("Text", Theme.text),
        ], id: \.0) { name, color in
            HStack {
                Circle().fill(color).frame(width: 28, height: 28)
                Text(name).foregroundStyle(Theme.text)
            }
        }
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .background(Theme.background)
}
