import Foundation

/// Corner slots, in Kociemba's order. The coordinate tables depend on this order.
enum Corner: Int, CaseIterable {
    case URF = 0, UFL, ULB, UBR, DFR, DLF, DBL, DRB
}

/// Edge slots, in Kociemba's order. FR/FL/BL/BR (8...11) are the UD-slice edges,
/// which is what makes the phase-1 "slice" coordinate cheap to compute.
enum Edge: Int, CaseIterable {
    case UR = 0, UF, UL, UB, DR, DF, DL, DB, FR, FL, BL, BR
}

/// A 3x3x3 state in cubie form: which cubie sits in each slot, and how it is twisted.
///
/// `cp[i]` is the corner *piece* occupying slot `i`, `co[i]` its twist (0/1/2 clockwise
/// from solved as seen from outside the U or D face). Same idea for `ep`/`eo`, where
/// edge orientation is 0 or 1.
struct CubieCube: Equatable, Sendable {
    var cp: [UInt8]
    var co: [UInt8]
    var ep: [UInt8]
    var eo: [UInt8]

    init(cp: [UInt8], co: [UInt8], ep: [UInt8], eo: [UInt8]) {
        self.cp = cp; self.co = co; self.ep = ep; self.eo = eo
    }

    static let solved = CubieCube(
        cp: [0, 1, 2, 3, 4, 5, 6, 7],
        co: [0, 0, 0, 0, 0, 0, 0, 0],
        ep: [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11],
        eo: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0])

    var isSolved: Bool { self == CubieCube.solved }

    /// self * other, i.e. apply `other` to this state.
    func multiplied(by other: CubieCube) -> CubieCube {
        var ncp = [UInt8](repeating: 0, count: 8)
        var nco = [UInt8](repeating: 0, count: 8)
        for i in 0..<8 {
            let piece = Int(other.cp[i])
            ncp[i] = cp[piece]
            nco[i] = (co[piece] + other.co[i]) % 3
        }
        var nep = [UInt8](repeating: 0, count: 12)
        var neo = [UInt8](repeating: 0, count: 12)
        for i in 0..<12 {
            let piece = Int(other.ep[i])
            nep[i] = ep[piece]
            neo[i] = (eo[piece] + other.eo[i]) % 2
        }
        return CubieCube(cp: ncp, co: nco, ep: nep, eo: neo)
    }

    func applying(_ move: Move) -> CubieCube {
        var result = self
        let generator = CubieCube.faceGenerator[move.face.rawValue]
        for _ in 0..<move.amount { result = result.multiplied(by: generator) }
        return result
    }

    func applying(_ moves: [Move]) -> CubieCube {
        moves.reduce(self) { $0.applying($1) }
    }

    // MARK: - The six clockwise quarter-turn generators

    /// Indexed by `Face.rawValue` (U, R, F, D, L, B).
    static let faceGenerator: [CubieCube] = [
        // U
        CubieCube(cp: [3, 0, 1, 2, 4, 5, 6, 7],
                  co: [0, 0, 0, 0, 0, 0, 0, 0],
                  ep: [3, 0, 1, 2, 4, 5, 6, 7, 8, 9, 10, 11],
                  eo: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]),
        // R
        CubieCube(cp: [4, 1, 2, 0, 7, 5, 6, 3],
                  co: [2, 0, 0, 1, 1, 0, 0, 2],
                  ep: [8, 1, 2, 3, 11, 5, 6, 7, 4, 9, 10, 0],
                  eo: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]),
        // F
        CubieCube(cp: [1, 5, 2, 3, 0, 4, 6, 7],
                  co: [1, 2, 0, 0, 2, 1, 0, 0],
                  ep: [0, 9, 2, 3, 4, 8, 6, 7, 1, 5, 10, 11],
                  eo: [0, 1, 0, 0, 0, 1, 0, 0, 1, 1, 0, 0]),
        // D
        CubieCube(cp: [0, 1, 2, 3, 5, 6, 7, 4],
                  co: [0, 0, 0, 0, 0, 0, 0, 0],
                  ep: [0, 1, 2, 3, 5, 6, 7, 4, 8, 9, 10, 11],
                  eo: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]),
        // L
        CubieCube(cp: [0, 2, 6, 3, 4, 1, 5, 7],
                  co: [0, 1, 2, 0, 0, 2, 1, 0],
                  ep: [0, 1, 10, 3, 4, 5, 9, 7, 8, 2, 6, 11],
                  eo: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]),
        // B
        CubieCube(cp: [0, 1, 3, 7, 4, 5, 2, 6],
                  co: [0, 0, 1, 2, 0, 0, 2, 1],
                  ep: [0, 1, 2, 11, 4, 5, 6, 10, 8, 9, 3, 7],
                  eo: [0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 1, 1])
    ]

    // MARK: - Random state

    /// A uniformly random reachable state: all 43,252,003,274,489,856,000 of them,
    /// each with equal probability. This is what makes the scramble fair - a fixed
    /// number of random moves is not uniform.
    static func random(using rng: inout some RandomNumberGenerator) -> CubieCube {
        var cp: [UInt8] = Array(0..<8)
        var ep: [UInt8] = Array(0..<12)
        cp.shuffle(using: &rng)
        ep.shuffle(using: &rng)
        // Corner and edge permutation parity must agree; if they don't, one swap fixes it.
        if parity(cp) != parity(ep) { ep.swapAt(0, 1) }

        var co = [UInt8](repeating: 0, count: 8)
        var total = 0
        for i in 0..<7 {
            co[i] = UInt8(Int.random(in: 0..<3, using: &rng))
            total += Int(co[i])
        }
        co[7] = UInt8((3 - total % 3) % 3)          // total twist must be 0 mod 3

        var eo = [UInt8](repeating: 0, count: 12)
        var flips = 0
        for i in 0..<11 {
            eo[i] = UInt8(Int.random(in: 0..<2, using: &rng))
            flips += Int(eo[i])
        }
        eo[11] = UInt8(flips % 2)                    // total flip must be even

        return CubieCube(cp: cp, co: co, ep: ep, eo: eo)
    }

    static func parity(_ perm: [UInt8]) -> Int {
        var p = 0
        for i in 1..<perm.count {
            for j in 0..<i where perm[j] > perm[i] { p += 1 }
        }
        return p % 2
    }
}
