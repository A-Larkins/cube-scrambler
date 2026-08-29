import Foundation

/// The coordinate encodings Kociemba's two-phase algorithm searches over.
///
/// A full 3x3 state space is 4.3 x 10^19 - far too big to search. The trick is to project
/// it onto a handful of small coordinates. Phase 1 only cares about orientation and which
/// slots the four middle-layer edges occupy (2187 x 2048 x 495); once those are solved the
/// cube is in the subgroup reachable by <U, D, R2, L2, F2, B2>, and phase 2 only cares
/// about three permutations (40320 x 40320 x 24). Each coordinate changes independently of
/// the others under a move, which is what makes the lookup tables possible.
enum Coordinates {

    // MARK: - Permutation indexing (Lehmer code; the identity is always 0)

    static func permutationIndex(_ perm: ArraySlice<UInt8>) -> Int {
        let values = Array(perm)
        let n = values.count
        var index = 0
        for i in 0..<n {
            var smaller = 0
            for j in (i + 1)..<n where values[j] < values[i] { smaller += 1 }
            index = index * (n - i) + smaller
        }
        return index
    }

    static func permutation(from index: Int, count n: Int) -> [UInt8] {
        var index = index
        var digits = [Int](repeating: 0, count: n)
        for i in stride(from: n - 1, through: 0, by: -1) {
            digits[i] = index % (n - i)
            index /= (n - i)
        }
        var available: [UInt8] = Array(0..<UInt8(n))
        var perm = [UInt8](repeating: 0, count: n)
        for i in 0..<n { perm[i] = available.remove(at: digits[i]) }
        return perm
    }

    /// Pascal's triangle, for the UD-slice combination index.
    static let binomial: [[Int]] = {
        var table = [[Int]](repeating: [Int](repeating: 0, count: 13), count: 13)
        for n in 0...12 {
            table[n][0] = 1
            for k in 1...12 where k <= n {
                table[n][k] = table[n - 1][k - 1] + (k <= n - 1 ? table[n - 1][k] : 0)
            }
        }
        return table
    }()

    static func choose(_ n: Int, _ k: Int) -> Int {
        (n < 0 || k < 0 || k > n) ? 0 : binomial[n][k]
    }

    // MARK: - Sizes

    static let twistCount = 2187        // 3^7 corner orientations
    static let flipCount = 2048         // 2^11 edge orientations
    static let sliceCount = 495         // C(12,4) placements of the middle-layer edges
    static let cornerPermCount = 40320  // 8!
    static let edge8PermCount = 40320   // 8! for the U- and D-layer edges
    static let slicePermCount = 24      // 4! for the middle-layer edges among themselves

    /// The ten moves that keep the cube inside phase 2's subgroup.
    static let phase2Moves: [Move] = [
        Move(.U, 1), Move(.U, 2), Move(.U, 3),
        Move(.D, 1), Move(.D, 2), Move(.D, 3),
        Move(.R, 2), Move(.L, 2), Move(.F, 2), Move(.B, 2)
    ]
}

extension CubieCube {

    // MARK: - Phase 1 coordinates

    /// Corner orientation. Zero exactly when no corner is twisted.
    var twist: Int {
        var value = 0
        for i in 0..<7 { value = value * 3 + Int(co[i]) }
        return value
    }

    mutating func setTwist(_ index: Int) {
        var index = index
        var total = 0
        for i in stride(from: 6, through: 0, by: -1) {
            co[i] = UInt8(index % 3)
            total += index % 3
            index /= 3
        }
        co[7] = UInt8((3 - total % 3) % 3)
    }

    /// Edge orientation. Zero exactly when no edge is flipped.
    var flip: Int {
        var value = 0
        for i in 0..<11 { value = value * 2 + Int(eo[i]) }
        return value
    }

    mutating func setFlip(_ index: Int) {
        var index = index
        var total = 0
        for i in stride(from: 10, through: 0, by: -1) {
            eo[i] = UInt8(index % 2)
            total += index % 2
            index /= 2
        }
        eo[11] = UInt8(total % 2)
    }

    /// Which four of the twelve edge slots hold the middle-layer edges, ignoring their
    /// order. Zero exactly when all four are already in the middle layer.
    var sliceCoordinate: Int {
        var value = 0
        var found = 0
        for j in stride(from: 11, through: 0, by: -1) where ep[j] >= 8 {
            value += Coordinates.choose(11 - j, found + 1)
            found += 1
        }
        return value
    }

    mutating func setSliceCoordinate(_ index: Int) {
        var remaining = index
        var slicePieces: [UInt8] = [8, 9, 10, 11]
        var otherPieces: [UInt8] = [0, 1, 2, 3, 4, 5, 6, 7]
        var placed = [UInt8?](repeating: nil, count: 12)

        var x = 4
        for j in 0..<12 where x > 0 {
            let c = Coordinates.choose(11 - j, x)
            if remaining - c >= 0 {
                placed[j] = slicePieces[4 - x]
                remaining -= c
                x -= 1
            }
        }
        var next = 0
        for j in 0..<12 where placed[j] == nil {
            placed[j] = otherPieces[next]
            next += 1
        }
        for j in 0..<12 { ep[j] = placed[j]! }
    }

    // MARK: - Phase 2 coordinates

    var cornerPermCoordinate: Int { Coordinates.permutationIndex(cp[0..<8]) }

    mutating func setCornerPermCoordinate(_ index: Int) {
        cp = Coordinates.permutation(from: index, count: 8)
    }

    /// Permutation of the eight U- and D-layer edges. Phase 2's move set never takes one
    /// of them out of that set, so eight entries are enough.
    var edge8PermCoordinate: Int { Coordinates.permutationIndex(ep[0..<8]) }

    mutating func setEdge8PermCoordinate(_ index: Int) {
        let perm = Coordinates.permutation(from: index, count: 8)
        for i in 0..<8 { ep[i] = perm[i] }
        for i in 8..<12 { ep[i] = UInt8(i) }
    }

    /// Permutation of the four middle-layer edges among their own slots.
    var slicePermCoordinate: Int {
        let slice: [UInt8] = (8..<12).map { ep[$0] - 8 }
        return Coordinates.permutationIndex(slice[0..<4])
    }

    mutating func setSlicePermCoordinate(_ index: Int) {
        let perm = Coordinates.permutation(from: index, count: 4)
        for i in 0..<4 { ep[8 + i] = perm[i] + 8 }
    }

    /// True once phase 1 is done: nothing twisted, nothing flipped, middle-layer edges
    /// home. From here the cube can be finished with <U, D, R2, L2, F2, B2> alone.
    var isInPhase2Subgroup: Bool {
        twist == 0 && flip == 0 && sliceCoordinate == 0
    }
}
