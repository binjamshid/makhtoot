import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Color helpers shared by every `MKTheme` conformer in `Themes/`.

extension Color {
    /// A color literal from a packed `0xRRGGBB` value.
    init(hex: UInt32) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }

    /// A dynamic color that resolves to `light` or `dark` depending on the
    /// active `UITraitCollection.userInterfaceStyle`. This is how every
    /// theme renders correctly in both color schemes from a single
    /// conformer instance (WS-01 packet §12 task 13 accept criterion).
    init(light: Color, dark: Color) {
        #if canImport(UIKit)
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
        #else
        self = light
        #endif
    }

    /// A darkened variant of a packed hex color, used to derive
    /// `primaryPressed` where the design handoff doesn't specify an
    /// explicit pressed hex (it only specifies the resting `primary`
    /// value per theme) ، matches how filled controls darken ~8–10% on
    /// press per the handoff's "Interactions & Behavior" section.
    static func darkened(hex: UInt32, by amount: Double = 0.12) -> Color {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        let factor = 1 - amount
        return Color(red: r * factor, green: g * factor, blue: b * factor)
    }
}
