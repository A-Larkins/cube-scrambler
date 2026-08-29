import SwiftUI
import AppKit

/// The one place sticker colours are defined. The 3D cube and the flat net both read from
/// here, so they can never drift apart.
enum Palette {

    static func stickerColor(_ face: Face) -> NSColor {
        switch face {
        case .U: return NSColor(calibratedRed: 0.97, green: 0.97, blue: 0.96, alpha: 1)  // white
        case .D: return NSColor(calibratedRed: 1.00, green: 0.83, blue: 0.05, alpha: 1)  // yellow
        case .F: return NSColor(calibratedRed: 0.00, green: 0.62, blue: 0.30, alpha: 1)  // green
        case .B: return NSColor(calibratedRed: 0.02, green: 0.35, blue: 0.76, alpha: 1)  // blue
        case .R: return NSColor(calibratedRed: 0.80, green: 0.11, blue: 0.14, alpha: 1)  // red
        case .L: return NSColor(calibratedRed: 1.00, green: 0.38, blue: 0.02, alpha: 1)  // orange
        }
    }

    /// Colour of the direction arrow, and of whatever the interface is pointing at.
    static let accentColor = NSColor(calibratedRed: 1.0, green: 0.72, blue: 0.10, alpha: 1)
    /// Plastic between the stickers.
    static let bodyColor = NSColor(white: 0.10, alpha: 1)

    static func sticker(_ face: Face) -> Color { Color(nsColor: stickerColor(face)) }
    static let accent = Color(nsColor: accentColor)
}
