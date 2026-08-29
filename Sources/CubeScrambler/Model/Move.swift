import Foundation

/// The six faces, in the order Kociemba's coordinate tables assume (U, R, F, D, L, B).
/// Do not reorder: the move tables in `CubieCube` are indexed by this raw value.
enum Face: Int, CaseIterable, Codable, Sendable {
    case U = 0, R, F, D, L, B

    var letter: String {
        switch self {
        case .U: return "U"
        case .R: return "R"
        case .F: return "F"
        case .D: return "D"
        case .L: return "L"
        case .B: return "B"
        }
    }

    /// Everyday name for the face, for the plain-English instruction.
    var spokenName: String {
        switch self {
        case .U: return "TOP"
        case .R: return "RIGHT"
        case .F: return "FRONT"
        case .D: return "BOTTOM"
        case .L: return "LEFT"
        case .B: return "BACK"
        }
    }

    /// Outward normal in scene space: +X right, +Y up, +Z toward the viewer.
    var outwardNormal: (x: Int, y: Int, z: Int) {
        switch self {
        case .U: return (0, 1, 0)
        case .R: return (1, 0, 0)
        case .F: return (0, 0, 1)
        case .D: return (0, -1, 0)
        case .L: return (-1, 0, 0)
        case .B: return (0, 0, -1)
        }
    }

    static func named(_ letter: Character) -> Face? {
        switch letter {
        case "U": return .U
        case "R": return .R
        case "F": return .F
        case "D": return .D
        case "L": return .L
        case "B": return .B
        default: return nil
        }
    }
}

/// A single face turn. `amount` is in quarter turns clockwise as seen from outside
/// that face: 1 = clockwise, 2 = half turn, 3 = counter-clockwise (the prime).
struct Move: Equatable, Hashable, Codable, Sendable {
    let face: Face
    let amount: Int

    init(_ face: Face, _ amount: Int) {
        self.face = face
        self.amount = ((amount % 4) + 4) % 4
    }

    var notation: String {
        switch amount {
        case 1: return face.letter
        case 2: return face.letter + "2"
        case 3: return face.letter + "'"
        default: return face.letter + "0"
        }
    }

    /// Prime notation using a real prime character rather than an apostrophe, for display.
    var prettyNotation: String {
        amount == 3 ? face.letter + "\u{2032}" : notation
    }

    var inverse: Move { Move(face, 4 - amount) }

    var isHalfTurn: Bool { amount == 2 }

    /// Index into the 18-move table: face * 3 + (amount - 1).
    var tableIndex: Int { face.rawValue * 3 + (amount - 1) }

    static func fromTableIndex(_ i: Int) -> Move {
        Move(Face(rawValue: i / 3)!, i % 3 + 1)
    }

    /// The 18 outer face turns, in table order.
    static let all: [Move] = (0..<18).map { Move.fromTableIndex($0) }

    static func parse(_ text: String) -> [Move] {
        var moves: [Move] = []
        var pending: Face?
        func flush(_ amount: Int) {
            if let f = pending { moves.append(Move(f, amount)) }
            pending = nil
        }
        for ch in text {
            if let face = Face.named(ch) {
                flush(1)
                pending = face
            } else if ch == "2" {
                flush(2)
            } else if ch == "'" || ch == "\u{2032}" {
                flush(3)
            } else if ch == " " || ch == "\n" || ch == "\t" {
                flush(1)
            }
        }
        flush(1)
        return moves
    }
}

extension Array where Element == Move {
    var notation: String { map(\.notation).joined(separator: " ") }
    var prettyNotation: String { map(\.prettyNotation).joined(separator: " ") }
    /// Reverse order, each move inverted - turns a solution into a scramble.
    var inverted: [Move] { reversed().map(\.inverse) }
}
