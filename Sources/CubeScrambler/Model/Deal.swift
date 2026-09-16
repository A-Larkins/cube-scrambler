import Foundation

/// Every position, numbered - the way a game of solitaire has a deal number.
///
/// The set of scrambles is finite: 3,674,160 on the 2x2 and 43,252,003,274,489,856,000 on
/// the 3x3. So each one can be given a number, and that number is all it takes to get the
/// same scramble back. Nothing is stored; the number *is* the position, packed into one
/// integer and unpacked again.
///
/// The packing is a mixed-radix odometer over the four things that make up a state:
///
///     deal = ((corners * edgePlacements + edges) * twists + twist) * flips + flip
///
/// Every combination is a real, reachable cube exactly once, because the two rules a cube
/// obeys - total twist divides by three, and corner and edge permutations have the same
/// parity - are built into the ranges rather than checked afterwards. The last corner's
/// twist and the last edge's flip are never stored (they are forced), and the second-to-last
/// edge is the one that carries the parity, which is why the edge part counts 12!/2 and not
/// 12!. That makes the numbering a bijection: every deal number is a cube, every cube has
/// exactly one deal number, and `DealTests` checks the round trip both ways.
enum Deal {

    /// A scramble and the deal number it came from, kept together so the interface can
    /// never show one with the other's number.
    struct Dealt: Sendable {
        let number: UInt128
        let moves: [Move]
    }

    // MARK: - How many

    /// 8! - arrangements of the corners.
    static let cornerPermCount: UInt128 = 40320
    /// 12!/2 - arrangements of the edges with the parity forced to match the corners.
    static let edgePermCount: UInt128 = 239_500_800
    /// 3^7 - corner twists, the eighth forced.
    static let twistCount = UInt128(Coordinates.twistCount)
    /// 2^11 - edge flips, the twelfth forced.
    static let flipCount = UInt128(Coordinates.flipCount)

    static func total(for puzzle: PuzzleKind) -> UInt128 {
        switch puzzle {
        case .three: return cornerPermCount * edgePermCount * twistCount * flipCount
        case .two: return UInt128(Scrambler222.stateCount)
        }
    }

    // MARK: - Number to cube, and back

    /// The cube this deal number stands for. `number` is 0-based; the interface adds one,
    /// so the first deal a person sees is 1.
    static func cube(for number: UInt128, puzzle: PuzzleKind) -> CubieCube {
        let number = number % total(for: puzzle)
        switch puzzle {
        case .three: return cube333(for: number)
        case .two: return cube222(for: Int(number))
        }
    }

    /// The deal number of a cube. The exact inverse of `cube(for:puzzle:)`.
    static func number(of cube: CubieCube, puzzle: PuzzleKind) -> UInt128 {
        switch puzzle {
        case .three: return number333(of: cube)
        case .two: return UInt128(state222(of: cube))
        }
    }

    // MARK: - 3x3

    private static func cube333(for number: UInt128) -> CubieCube {
        var rest = number
        let flip = Int(rest % flipCount); rest /= flipCount
        let twist = Int(rest % twistCount); rest /= twistCount
        let edges = rest % edgePermCount; rest /= edgePermCount
        let corners = Int(rest % cornerPermCount)

        var cube = CubieCube.solved
        cube.cp = Coordinates.permutation(from: corners, count: 8)
        cube.ep = edgePermutation(from: edges, parity: CubieCube.parity(cube.cp))
        cube.setTwist(twist)
        cube.setFlip(flip)
        return cube
    }

    private static func number333(of cube: CubieCube) -> UInt128 {
        let corners = UInt128(Coordinates.permutationIndex(cube.cp[0...]))
        let edges = edgeIndex(of: cube.ep)
        return ((corners * edgePermCount + edges) * twistCount + UInt128(cube.twist))
            * flipCount + UInt128(cube.flip)
    }

    /// Lehmer digits of an edge permutation: `digits[i]` is how many of the edges after
    /// position `i` belong before it. The permutation's parity is the sum of the digits.
    private static func lehmerDigits(_ perm: [UInt8]) -> [Int] {
        (0..<perm.count).map { i in
            ((i + 1)..<perm.count).reduce(0) { $0 + (perm[$1] < perm[i] ? 1 : 0) }
        }
    }

    /// Edge arrangements, counted with the last two positions left out of the index: the
    /// eleventh digit is whatever parity demands, and the twelfth is always zero.
    private static func edgeIndex(of perm: [UInt8]) -> UInt128 {
        let digits = lehmerDigits(perm)
        var index: UInt128 = 0
        for i in 0..<10 { index = index * UInt128(12 - i) + UInt128(digits[i]) }
        return index
    }

    private static func edgePermutation(from index: UInt128, parity: Int) -> [UInt8] {
        var index = index
        var digits = [Int](repeating: 0, count: 12)
        for i in stride(from: 9, through: 0, by: -1) {
            digits[i] = Int(index % UInt128(12 - i))
            index /= UInt128(12 - i)
        }
        // The one free choice left decides whether the edges are an odd or an even
        // arrangement, and that has to match the corners or the cube cannot be built.
        digits[10] = (parity - digits.prefix(10).reduce(0, +) % 2 + 2) % 2
        digits[11] = 0

        var available: [UInt8] = Array(0..<12)
        var perm = [UInt8](repeating: 0, count: 12)
        for i in 0..<12 { perm[i] = available.remove(at: digits[i]) }
        return perm
    }

    // MARK: - 2x2

    private static func cube222(for state: Int) -> CubieCube {
        let perm = Scrambler222.permutation(from: state / Scrambler222.orientationCount)
        let ori = Scrambler222.orientation(from: state % Scrambler222.orientationCount)
        var cube = CubieCube.solved
        for k in 0..<7 {
            let slot = Scrambler222.slots[k].rawValue
            cube.cp[slot] = UInt8(Scrambler222.slots[Int(perm[k])].rawValue)
            cube.co[slot] = ori[k]
        }
        return cube
    }

    private static func state222(of cube: CubieCube) -> Int {
        Scrambler222.stateIndex(of: cube)
    }

    // MARK: - Reading and writing the number

    /// Grouped in threes, so a twenty-digit number can be read at all.
    static func formatted(_ number: UInt128) -> String {
        let digits = Array(String(number))
        var out = ""
        for (offset, digit) in digits.enumerated() {
            if offset > 0 && (digits.count - offset) % 3 == 0 { out.append(",") }
            out.append(digit)
        }
        return out
    }

    /// Reads what someone typed, in the 1-based numbering the interface shows, and returns
    /// it 0-based. Punctuation and spaces are ignored, so a number can be pasted back in
    /// exactly as it was displayed.
    static func parse(_ text: String, puzzle: PuzzleKind) -> UInt128? {
        let digits = text.filter(\.isNumber)
        guard !digits.isEmpty, let value = UInt128(digits), value >= 1,
              value <= total(for: puzzle) else { return nil }
        return value - 1
    }
}
