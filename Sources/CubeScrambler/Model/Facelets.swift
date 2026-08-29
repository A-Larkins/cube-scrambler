import Foundation

enum PuzzleKind: String, CaseIterable, Codable, Sendable {
    case three = "333"
    case two = "222"

    var size: Int { self == .three ? 3 : 2 }
    var displayName: String { self == .three ? "3\u{00D7}3" : "2\u{00D7}2" }
}

/// The colour of a sticker, named by the face it belongs to on a solved cube.
/// Standard Western scheme with white up and green front.
extension Face {
    var stickerName: String {
        switch self {
        case .U: return "white"
        case .R: return "red"
        case .F: return "green"
        case .D: return "yellow"
        case .L: return "orange"
        case .B: return "blue"
        }
    }
}

/// Every sticker on the cube, as the face whose colour it shows.
///
/// One representation drives both the 3D scene and the 2D net, so they can never
/// disagree about what the cube looks like.
struct Facelets: Equatable {
    let size: Int
    /// `size * size` entries per face, in Face raw-value order (U, R, F, D, L, B).
    var colors: [Face]

    static func solved(size: Int) -> Facelets {
        var colors: [Face] = []
        for face in Face.allCases {
            colors.append(contentsOf: Array(repeating: face, count: size * size))
        }
        return Facelets(size: size, colors: colors)
    }

    subscript(index: Int) -> Face { colors[index] }

    /// Sticker on `face` at grid position (row, col), row 0 at the top as that face
    /// is conventionally drawn.
    func color(face: Face, row: Int, col: Int) -> Face {
        colors[face.rawValue * size * size + row * size + col]
    }

    // MARK: - Geometry

    /// Index of the sticker on `face` belonging to the cubie at integer lattice
    /// position (cx, cy, cz), each in 0..<size with 0 at the left/bottom/back.
    ///
    /// This is the single bridge between "cube state" and "something drawn on screen".
    static func index(face: Face, cx: Int, cy: Int, cz: Int, size n: Int) -> Int {
        let last = n - 1
        let row: Int, col: Int
        switch face {
        case .U: row = cz;        col = cx
        case .R: row = last - cy; col = last - cz
        case .F: row = last - cy; col = cx
        case .D: row = last - cz; col = cx
        case .L: row = last - cy; col = cz
        case .B: row = last - cy; col = last - cx
        }
        return face.rawValue * n * n + row * n + col
    }

    /// Does the cubie at this lattice position carry a sticker on `face`? Only cubies in
    /// a face's outer layer show that face's colour.
    static func carries(_ face: Face, cx: Int, cy: Int, cz: Int, size n: Int) -> Bool {
        let last = n - 1
        switch face {
        case .U: return cy == last
        case .D: return cy == 0
        case .R: return cx == last
        case .L: return cx == 0
        case .F: return cz == last
        case .B: return cz == 0
        }
    }

    /// Cubies with no sticker at all are never built - on a 3x3 that is the core.
    static func isVisible(cx: Int, cy: Int, cz: Int, size n: Int) -> Bool {
        Face.allCases.contains { carries($0, cx: cx, cy: cy, cz: cz, size: n) }
    }

    /// Lattice position of a corner slot, in 0..<size coordinates.
    static func position(of corner: Corner, size n: Int) -> (x: Int, y: Int, z: Int) {
        let last = n - 1
        switch corner {
        case .URF: return (last, last, last)
        case .UFL: return (0, last, last)
        case .ULB: return (0, last, 0)
        case .UBR: return (last, last, 0)
        case .DFR: return (last, 0, last)
        case .DLF: return (0, 0, last)
        case .DBL: return (0, 0, 0)
        case .DRB: return (last, 0, 0)
        }
    }

    /// Lattice position of an edge slot on a 3x3.
    static func position(of edge: Edge) -> (x: Int, y: Int, z: Int) {
        switch edge {
        case .UR: return (2, 2, 1)
        case .UF: return (1, 2, 2)
        case .UL: return (0, 2, 1)
        case .UB: return (1, 2, 0)
        case .DR: return (2, 0, 1)
        case .DF: return (1, 0, 2)
        case .DL: return (0, 0, 1)
        case .DB: return (1, 0, 0)
        case .FR: return (2, 1, 2)
        case .FL: return (0, 1, 2)
        case .BL: return (0, 1, 0)
        case .BR: return (2, 1, 0)
        }
    }

    // MARK: - Kociemba's sticker tables (3x3 indices)

    /// The three stickers of each corner slot, listed in the twist order the `co`
    /// values are measured against.
    static let cornerFacelet: [[Int]] = [
        [8, 9, 20],   // URF: U9 R1 F3
        [6, 18, 38],  // UFL: U7 F1 L3
        [0, 36, 47],  // ULB: U1 L1 B3
        [2, 45, 11],  // UBR: U3 B1 R3
        [29, 26, 15], // DFR: D3 F9 R7
        [27, 44, 24], // DLF: D1 L9 F7
        [33, 53, 42], // DBL: D7 B9 L7
        [35, 17, 51]  // DRB: D9 R9 B7
    ]

    static let edgeFacelet: [[Int]] = [
        [5, 10],  // UR: U6 R2
        [7, 19],  // UF: U8 F2
        [3, 37],  // UL: U4 L2
        [1, 46],  // UB: U2 B2
        [32, 16], // DR: D6 R8
        [28, 25], // DF: D2 F8
        [30, 43], // DL: D4 L8
        [34, 52], // DB: D8 B8
        [23, 12], // FR: F6 R4
        [21, 41], // FL: F4 L6
        [50, 39], // BL: B6 L4
        [48, 14]  // BR: B4 R6
    ]

    /// Home face of each sticker: a 3x3 facelet index divided by 9.
    static func homeFace(of faceletIndex: Int) -> Face {
        Face(rawValue: faceletIndex / 9)!
    }

    /// Rewrites a 3x3 facelet index as the equivalent index on a 2x2. Corner stickers
    /// always sit at a corner of their face grid, so row/col 0 stays 0 and 2 becomes 1.
    static func twoByTwoIndex(from index3: Int) -> Int {
        let face = index3 / 9
        let row = (index3 % 9) / 3
        let col = (index3 % 9) % 3
        return face * 4 + (row == 0 ? 0 : 1) * 2 + (col == 0 ? 0 : 1)
    }

    // MARK: - Building from a state

    /// Sticker colours for a 3x3 state.
    static func from(cube: CubieCube) -> Facelets {
        // Start solved so the six centres - which never move and have no cubie entry to
        // read them from - are already the right colour.
        var colors = Facelets.solved(size: 3).colors
        for slot in Corner.allCases {
            let piece = Int(cube.cp[slot.rawValue])
            let twist = Int(cube.co[slot.rawValue])
            for k in 0..<3 {
                let sticker = cornerFacelet[slot.rawValue][(k + twist) % 3]
                colors[sticker] = homeFace(of: cornerFacelet[piece][k])
            }
        }
        for slot in Edge.allCases {
            let piece = Int(cube.ep[slot.rawValue])
            let flip = Int(cube.eo[slot.rawValue])
            for k in 0..<2 {
                let sticker = edgeFacelet[slot.rawValue][(k + flip) % 2]
                colors[sticker] = homeFace(of: edgeFacelet[piece][k])
            }
        }
        return Facelets(size: 3, colors: colors)
    }

    /// Sticker colours for a 2x2 state, held in the corner fields of a `CubieCube`.
    static func fromCorners(cube: CubieCube) -> Facelets {
        var colors = [Face](repeating: .U, count: 24)
        for slot in Corner.allCases {
            let piece = Int(cube.cp[slot.rawValue])
            let twist = Int(cube.co[slot.rawValue])
            for k in 0..<3 {
                let sticker = twoByTwoIndex(from: cornerFacelet[slot.rawValue][(k + twist) % 3])
                colors[sticker] = homeFace(of: cornerFacelet[piece][k])
            }
        }
        return Facelets(size: 2, colors: colors)
    }

    static func from(cube: CubieCube, puzzle: PuzzleKind) -> Facelets {
        puzzle == .three ? from(cube: cube) : fromCorners(cube: cube)
    }
}
