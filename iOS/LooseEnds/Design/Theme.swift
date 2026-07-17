import SwiftUI

/// Bespoke electric-lime-on-charcoal palette — deliberately the most
/// saturated, highest-energy look in this batch. Lime is used everywhere
/// something should feel alive (notes, bins, the capture button); charcoal
/// is the calm, empty desk it all lands on.
enum LooseEndsTheme {
    static let charcoal = Color(red: 0x12 / 255, green: 0x12 / 255, blue: 0x14 / 255)
    static let panel = Color(red: 0x1C / 255, green: 0x1E / 255, blue: 0x21 / 255)
    static let binFill = Color(red: 0x24 / 255, green: 0x27 / 255, blue: 0x2B / 255)
    static let hairline = Color(red: 0x33 / 255, green: 0x37 / 255, blue: 0x3C / 255)

    static let lime = Color(red: 0xD7 / 255, green: 0xFF / 255, blue: 0x3E / 255)
    static let limeBright = Color(red: 0xEA / 255, green: 0xFF / 255, blue: 0x8C / 255)
    static let limeDeep = Color(red: 0x9F / 255, green: 0xCC / 255, blue: 0x00 / 255)

    static let ink = Color(red: 0x14 / 255, green: 0x15 / 255, blue: 0x0F / 255)
    static let offWhite = Color(red: 0xF4 / 255, green: 0xF5 / 255, blue: 0xF0 / 255)
    static let mutedText = Color(red: 0x9B / 255, green: 0xA3 / 255, blue: 0x9B / 255)

    static let backgroundGradient = LinearGradient(
        colors: [charcoal, Color(red: 0x0B / 255, green: 0x0C / 255, blue: 0x0D / 255)],
        startPoint: .top,
        endPoint: .bottom
    )

    static let noteGradient = LinearGradient(
        colors: [limeBright, lime],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

extension View {
    /// Standard dark glass panel used for sheets and cards.
    func looseEndsPanel(cornerRadius: CGFloat = 22) -> some View {
        self.background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(LooseEndsTheme.panel)
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(LooseEndsTheme.hairline, lineWidth: 1)
                )
        )
    }
}
