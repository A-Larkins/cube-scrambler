import Foundation

/// The six sticker colours of a standard cube.
enum StickerColor: String, CaseIterable, Sendable {
    case white, yellow, green, blue, red, orange

    var name: String { rawValue }
}

/// Which way round you hold the cube before you start scrambling.
///
/// Notation is relative to the holder - U is whatever is on top, F whatever faces you -
/// so the moves themselves never change. What changes is which colour sits on each face,
/// and that is all this decides. A random-state scramble stays exactly as random whichever
/// colour is on top, since holding the cube differently is just a relabelling of the
/// same 43 quintillion positions.
enum Hold: String, CaseIterable, Sendable {
    /// Blue facing you, white centre on the bottom. Yellow ends up on top, red on the
    /// right (it's the standard cube turned over forwards, which keeps red on the right).
    case blueFrontWhiteDown = "blue-front-white-down"
    /// The WCA scrambling orientation.
    case greenFrontWhiteUp = "green-front-white-up"

    static let standard: Hold = .blueFrontWhiteDown

    var displayName: String {
        switch self {
        case .blueFrontWhiteDown: return "Blue front, white down"
        case .greenFrontWhiteUp: return "Green front, white up"
        }
    }

    /// The colour of the centre on `face` while the cube is held this way.
    func color(of face: Face) -> StickerColor {
        switch self {
        case .blueFrontWhiteDown:
            switch face {
            case .U: return .yellow
            case .D: return .white
            case .F: return .blue
            case .B: return .green
            case .R: return .red
            case .L: return .orange
            }
        case .greenFrontWhiteUp:
            switch face {
            case .U: return .white
            case .D: return .yellow
            case .F: return .green
            case .B: return .blue
            case .R: return .red
            case .L: return .orange
            }
        }
    }

    /// One line telling you how to pick the cube up.
    var instruction: String {
        "Hold it with \(color(of: .F).name) facing you and \(color(of: .U).name) on top "
            + "(\(color(of: .D).name) on the bottom)."
    }
}
