import Foundation

/// Exact random-state scrambler for the 2x2x2.
///
/// A 2x2 has no centres, so one corner can be held still and every state reached with
/// only U, R and F turns - which is also the standard notation for the event. Holding
/// the DBL corner fixed leaves 7 corners: 7! arrangements times 3^6 twists (the last
/// twist is forced, since the total must be 0 mod 3) = 3,674,160 states. That is small
/// enough to solve *perfectly*: one breadth-first search from solved measures the exact
/// distance to every state, so scrambles are uniformly random AND optimally short.
enum Scrambler222 {

    /// The seven corner slots that U, R and F can touch. DBL is deliberately absent.
    static let slots: [Corner] = [.URF, .UFL, .ULB, .UBR, .DFR, .DLF, .DRB]

    static let permutationCount = 5040          // 7!
    static let orientationCount = 729           // 3^6
    static let stateCount = permutationCount * orientationCount

    /// U, U2, U', R, R2, R', F, F2, F'
    static let moves: [Move] = [Face.U, .R, .F].flatMap { face in
        (1...3).map { Move(face, $0) }
    }

    static let unvisited: UInt8 = 255
    private static let cacheName = "distances-222-v1.bin"

    // MARK: - Coordinates

    /// Position in `slots` of a given corner slot, or nil for DBL.
    private static let slotIndex: [Int] = {
        var table = [Int](repeating: -1, count: 8)
        for (i, slot) in slots.enumerated() { table[slot.rawValue] = i }
        return table
    }()

    /// Lehmer code of a permutation of 0..<7.
    static func permutationIndex(_ perm: [UInt8]) -> Int {
        var index = 0
        for i in 0..<7 {
            var smaller = 0
            for j in (i + 1)..<7 where perm[j] < perm[i] { smaller += 1 }
            index = index * (7 - i) + smaller
        }
        return index
    }

    static func permutation(from index: Int) -> [UInt8] {
        var index = index
        var digits = [Int](repeating: 0, count: 7)
        for i in stride(from: 6, through: 0, by: -1) {
            digits[i] = index % (7 - i)
            index /= (7 - i)
        }
        var available: [UInt8] = Array(0..<7)
        var perm = [UInt8](repeating: 0, count: 7)
        for i in 0..<7 { perm[i] = available.remove(at: digits[i]) }
        return perm
    }

    /// Twists of the first six corners in base 3; the seventh is forced.
    static func orientationIndex(_ ori: [UInt8]) -> Int {
        var index = 0
        for i in 0..<6 { index = index * 3 + Int(ori[i]) }
        return index
    }

    static func orientation(from index: Int) -> [UInt8] {
        var index = index
        var ori = [UInt8](repeating: 0, count: 7)
        var total = 0
        for i in stride(from: 5, through: 0, by: -1) {
            ori[i] = UInt8(index % 3)
            total += index % 3
            index /= 3
        }
        ori[6] = UInt8((3 - total % 3) % 3)
        return ori
    }

    // MARK: - Move tables

    /// `permutationMove[index * 9 + m]` - where the permutation coordinate goes.
    /// Permutation and orientation transition independently: the new twist at a slot is
    /// the old twist of whichever piece arrives plus the move's own twist, and both of
    /// those depend only on the move, never on the rest of the state.
    static let permutationMove: [Int32] = buildPermutationMoves()
    static let orientationMove: [Int32] = buildOrientationMoves()

    private static func buildPermutationMoves() -> [Int32] {
        var table = [Int32](repeating: 0, count: permutationCount * moves.count)
        for index in 0..<permutationCount {
            let perm = permutation(from: index)
            for (m, move) in moves.enumerated() {
                var current = perm
                for _ in 0..<move.amount { current = applyPermutation(move.face, to: current) }
                table[index * moves.count + m] = Int32(permutationIndex(current))
            }
        }
        return table
    }

    private static func buildOrientationMoves() -> [Int32] {
        var table = [Int32](repeating: 0, count: orientationCount * moves.count)
        for index in 0..<orientationCount {
            let ori = orientation(from: index)
            for (m, move) in moves.enumerated() {
                var current = ori
                for _ in 0..<move.amount { current = applyOrientation(move.face, to: current) }
                table[index * moves.count + m] = Int32(orientationIndex(current))
            }
        }
        return table
    }

    private static func applyPermutation(_ face: Face, to perm: [UInt8]) -> [UInt8] {
        let generator = CubieCube.faceGenerator[face.rawValue]
        var result = [UInt8](repeating: 0, count: 7)
        for k in 0..<7 {
            let source = slotIndex[Int(generator.cp[slots[k].rawValue])]
            result[k] = perm[source]
        }
        return result
    }

    private static func applyOrientation(_ face: Face, to ori: [UInt8]) -> [UInt8] {
        let generator = CubieCube.faceGenerator[face.rawValue]
        var result = [UInt8](repeating: 0, count: 7)
        for k in 0..<7 {
            let slot = slots[k].rawValue
            let source = slotIndex[Int(generator.cp[slot])]
            result[k] = (ori[source] + generator.co[slot]) % 3
        }
        return result
    }

    static func stateIndex(permutation p: Int, orientation o: Int) -> Int {
        p * orientationCount + o
    }

    // MARK: - The distance table

    /// Exact distance from solved to every state, in quarter and half turns.
    /// God's number for the 2x2 in this metric is 11, so no entry exceeds 11.
    static let distances: [UInt8] = TableCache.loadOrBuild(cacheName, count: stateCount) {
        buildDistances()
    }

    static func buildDistances() -> [UInt8] {
        let moveCount = moves.count
        var distance = [UInt8](repeating: unvisited, count: stateCount)
        let solved = stateIndex(permutation: permutationIndex(Array(0..<7)),
                                orientation: orientationIndex([UInt8](repeating: 0, count: 7)))
        distance[solved] = 0

        var frontier: [Int32] = [Int32(solved)]
        var depth: UInt8 = 0
        distance.withUnsafeMutableBufferPointer { dist in
            permutationMove.withUnsafeBufferPointer { permMoves in
                orientationMove.withUnsafeBufferPointer { oriMoves in
                    while !frontier.isEmpty {
                        depth += 1
                        var next: [Int32] = []
                        next.reserveCapacity(frontier.count * 4)
                        for state in frontier {
                            let p = Int(state) / orientationCount
                            let o = Int(state) % orientationCount
                            for m in 0..<moveCount {
                                let np = Int(permMoves[p * moveCount + m])
                                let no = Int(oriMoves[o * moveCount + m])
                                let ns = np * orientationCount + no
                                if dist[ns] == unvisited {
                                    dist[ns] = depth
                                    next.append(Int32(ns))
                                }
                            }
                        }
                        frontier = next
                    }
                }
            }
        }
        return distance
    }

    // MARK: - Scrambling

    /// A uniformly random state, scrambled with the shortest sequence that reaches it.
    static func scramble(using rng: inout some RandomNumberGenerator) -> [Move] {
        let table = distances
        while true {
            let state = Int.random(in: 0..<stateCount, using: &rng)
            let solution = solve(state: state, distances: table)
            // A near-solved cube is a legal random draw but a useless scramble; it is
            // rare enough (fewer than 1 in 10,000) that redrawing costs nothing.
            if solution.count >= 4 { return solution.inverted }
        }
    }

    /// Walks a state down the distance table to solved. Every step is guaranteed to
    /// exist, because a state at distance d always has a neighbour at distance d-1.
    static func solve(state: Int, distances table: [UInt8]) -> [Move] {
        var current = state
        var solution: [Move] = []
        let moveCount = moves.count
        while table[current] > 0 {
            let target = table[current] - 1
            let p = current / orientationCount
            let o = current % orientationCount
            for m in 0..<moveCount {
                let np = Int(permutationMove[p * moveCount + m])
                let no = Int(orientationMove[o * moveCount + m])
                let ns = np * orientationCount + no
                if table[ns] == target {
                    solution.append(moves[m])
                    current = ns
                    break
                }
            }
        }
        return solution
    }

    /// The state index of a cube built by applying `moves` to a solved cube.
    static func stateIndex(after moves: [Move]) -> Int {
        stateIndex(of: CubieCube.solved.applying(moves))
    }

    /// Where a cube sits in the 3,674,160 states, reading only its seven moving corners.
    static func stateIndex(of cube: CubieCube) -> Int {
        var perm = [UInt8](repeating: 0, count: 7)
        var ori = [UInt8](repeating: 0, count: 7)
        for k in 0..<7 {
            perm[k] = UInt8(slotIndex[Int(cube.cp[slots[k].rawValue])])
            ori[k] = cube.co[slots[k].rawValue]
        }
        return stateIndex(permutation: permutationIndex(perm), orientation: orientationIndex(ori))
    }
}
