import Foundation

/// The lookup tables Kociemba's two-phase search runs on.
///
/// Two kinds of table. *Move* tables answer "this coordinate, that move, what now?" in one
/// array read. *Pruning* tables hold the exact number of moves each coordinate pair still
/// needs, found by breadth-first search from the goal; the search uses them as an
/// admissible lower bound, which is what keeps the tree small enough to walk.
///
/// Building them takes a moment, so the pruning tables - the expensive half - are written
/// to Application Support and reloaded on later launches. They are pure derived data.
final class Tables333 {

    static let shared = Tables333()

    private static let pruningCacheName = "pruning-333-v1.bin"
    static let unreachable: UInt8 = 255

    // MARK: - Move tables

    let twistMove: [Int32]        // [twist][18]
    let flipMove: [Int32]         // [flip][18]
    let sliceMove: [Int32]        // [slice][18]
    let cornerPermMove: [Int32]   // [cornerPerm][10]
    let edge8PermMove: [Int32]    // [edge8Perm][10]
    let slicePermMove: [Int32]    // [slicePerm][10]

    // MARK: - Pruning tables

    /// Moves still needed to reach the phase-2 subgroup, lower-bounded by each pair.
    let sliceTwistPrune: [UInt8]  // [slice * 2187 + twist]
    let sliceFlipPrune: [UInt8]   // [slice * 2048 + flip]
    /// Moves still needed to finish, once inside the subgroup.
    let cornerPrune: [UInt8]      // [slicePerm * 40320 + cornerPerm]
    let edge8Prune: [UInt8]       // [slicePerm * 40320 + edge8Perm]

    private init() {
        let allMoves = Move.all
        let phase2 = Coordinates.phase2Moves

        twistMove = Tables333.buildMoveTable(count: Coordinates.twistCount, moves: allMoves) {
            var cube = CubieCube.solved; cube.setTwist($0); return cube
        } read: { $0.twist }

        flipMove = Tables333.buildMoveTable(count: Coordinates.flipCount, moves: allMoves) {
            var cube = CubieCube.solved; cube.setFlip($0); return cube
        } read: { $0.flip }

        sliceMove = Tables333.buildMoveTable(count: Coordinates.sliceCount, moves: allMoves) {
            var cube = CubieCube.solved; cube.setSliceCoordinate($0); return cube
        } read: { $0.sliceCoordinate }

        cornerPermMove = Tables333.buildMoveTable(count: Coordinates.cornerPermCount,
                                                  moves: phase2) {
            var cube = CubieCube.solved; cube.setCornerPermCoordinate($0); return cube
        } read: { $0.cornerPermCoordinate }

        edge8PermMove = Tables333.buildMoveTable(count: Coordinates.edge8PermCount,
                                                 moves: phase2) {
            var cube = CubieCube.solved; cube.setEdge8PermCoordinate($0); return cube
        } read: { $0.edge8PermCoordinate }

        slicePermMove = Tables333.buildMoveTable(count: Coordinates.slicePermCount,
                                                 moves: phase2) {
            var cube = CubieCube.solved; cube.setSlicePermCoordinate($0); return cube
        } read: { $0.slicePermCoordinate }

        // The four pruning tables live in one cache file, in this order.
        let sizes = [Coordinates.sliceCount * Coordinates.twistCount,
                     Coordinates.sliceCount * Coordinates.flipCount,
                     Coordinates.slicePermCount * Coordinates.cornerPermCount,
                     Coordinates.slicePermCount * Coordinates.edge8PermCount]
        let total = sizes.reduce(0, +)

        let twistMoveLocal = twistMove, flipMoveLocal = flipMove, sliceMoveLocal = sliceMove
        let cornerMoveLocal = cornerPermMove, edgeMoveLocal = edge8PermMove
        let sliceP2MoveLocal = slicePermMove

        let blob = TableCache.loadOrBuild(Tables333.pruningCacheName, count: total) {
            var out = [UInt8]()
            out.reserveCapacity(total)
            out += Tables333.buildPruning(
                sizeA: Coordinates.sliceCount, movesA: sliceMoveLocal,
                sizeB: Coordinates.twistCount, movesB: twistMoveLocal, moveCount: 18)
            out += Tables333.buildPruning(
                sizeA: Coordinates.sliceCount, movesA: sliceMoveLocal,
                sizeB: Coordinates.flipCount, movesB: flipMoveLocal, moveCount: 18)
            out += Tables333.buildPruning(
                sizeA: Coordinates.slicePermCount, movesA: sliceP2MoveLocal,
                sizeB: Coordinates.cornerPermCount, movesB: cornerMoveLocal, moveCount: 10)
            out += Tables333.buildPruning(
                sizeA: Coordinates.slicePermCount, movesA: sliceP2MoveLocal,
                sizeB: Coordinates.edge8PermCount, movesB: edgeMoveLocal, moveCount: 10)
            return out
        }

        var offset = 0
        func slice(_ length: Int) -> [UInt8] {
            defer { offset += length }
            return Array(blob[offset..<(offset + length)])
        }
        sliceTwistPrune = slice(sizes[0])
        sliceFlipPrune = slice(sizes[1])
        cornerPrune = slice(sizes[2])
        edge8Prune = slice(sizes[3])
    }

    // MARK: - Building

    private static func buildMoveTable(count: Int,
                                       moves: [Move],
                                       make: (Int) -> CubieCube,
                                       read: (CubieCube) -> Int) -> [Int32] {
        var table = [Int32](repeating: 0, count: count * moves.count)
        for index in 0..<count {
            let cube = make(index)
            for (m, move) in moves.enumerated() {
                table[index * moves.count + m] = Int32(read(cube.applying(move)))
            }
        }
        return table
    }

    /// Breadth-first search over the product of two coordinates, from the solved pair.
    ///
    /// Both coordinates change independently under a move, so the pair can be advanced
    /// with two array reads and no cube arithmetic. The move set is closed under inverses,
    /// so distance *from* solved is the same as distance *to* solved - which is what makes
    /// a forward search usable as a backward heuristic.
    private static func buildPruning(sizeA: Int, movesA: [Int32],
                                     sizeB: Int, movesB: [Int32],
                                     moveCount: Int) -> [UInt8] {
        var distance = [UInt8](repeating: unreachable, count: sizeA * sizeB)
        distance[0] = 0
        var frontier: [Int32] = [0]
        var depth: UInt8 = 0

        distance.withUnsafeMutableBufferPointer { dist in
            movesA.withUnsafeBufferPointer { ma in
                movesB.withUnsafeBufferPointer { mb in
                    while !frontier.isEmpty {
                        depth += 1
                        var next: [Int32] = []
                        next.reserveCapacity(frontier.count * 3)
                        for state in frontier {
                            let a = Int(state) / sizeB
                            let b = Int(state) % sizeB
                            for m in 0..<moveCount {
                                let na = Int(ma[a * moveCount + m])
                                let nb = Int(mb[b * moveCount + m])
                                let ns = na * sizeB + nb
                                if dist[ns] == unreachable {
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
}
