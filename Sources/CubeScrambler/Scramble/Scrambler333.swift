import Foundation

/// Random-state scrambler for the 3x3x3, using Kociemba's two-phase algorithm.
///
/// Pick a uniformly random state, solve it, and turn the solution round: the inverse of a
/// solution *is* a scramble that produces that exact state. Solving is what needs the
/// cleverness - a layer-by-layer solve would work but would give a 60-move scramble, so
/// the two-phase search is what keeps it down to the 18-20 moves you would see at a
/// competition.
enum Scrambler333 {

    /// Stop searching once a solution this short turns up; almost always immediate.
    static let goodEnoughLength = 20
    /// Never return anything longer than this.
    static let maximumLength = 22

    static func scramble(using rng: inout some RandomNumberGenerator) -> [Move] {
        let target = CubieCube.random(using: &rng)
        return solve(target).inverted
    }

    static func solve(_ cube: CubieCube,
                      timeBudget: TimeInterval = 0.75) -> [Move] {
        TwoPhaseSolver(cube: cube, timeBudget: timeBudget).run()
    }
}

/// One run of the search. Holds the mutable bookkeeping so the recursion stays cheap.
private final class TwoPhaseSolver {

    private let tables = Tables333.shared
    private let cube: CubieCube
    private let deadline: Date

    private var phase1Path: [Int] = []      // indices into Move.all
    private var phase2Path: [Int] = []      // indices into Coordinates.phase2Moves
    private var best: [Move]?

    init(cube: CubieCube, timeBudget: TimeInterval) {
        self.cube = cube
        self.deadline = Date().addingTimeInterval(timeBudget)
    }

    func run() -> [Move] {
        if cube.isSolved { return [] }

        let twist = cube.twist
        let flip = cube.flip
        let slice = cube.sliceCoordinate

        // Iterative deepening on phase 1. Each new depth offers more ways into the
        // subgroup, and a phase-1 solution one move longer often buys back several in
        // phase 2, so it is worth looking past the first one that works.
        for depth in 0...12 {
            phase1Path.removeAll(keepingCapacity: true)
            searchPhase1(twist: twist, flip: flip, slice: slice,
                         remaining: depth, lastFace: -1)
            if let best, best.count <= Scrambler333.goodEnoughLength { break }
            if Date() >= deadline, best != nil { break }
        }

        // The search is exhaustive by depth, so this only fires if the budget ran out
        // before any phase-1 depth completed - which needs a pathological machine.
        return best ?? []
    }

    // MARK: - Phase 1: reach <U, D, R2, L2, F2, B2>

    private func searchPhase1(twist: Int, flip: Int, slice: Int,
                              remaining: Int, lastFace: Int) {
        let lowerBound = max(tables.sliceTwistPrune[slice * Coordinates.twistCount + twist],
                             tables.sliceFlipPrune[slice * Coordinates.flipCount + flip])
        if Int(lowerBound) > remaining { return }

        if remaining == 0 {
            // lowerBound == 0 means nothing twisted, nothing flipped, slice edges home.
            if lowerBound == 0 { finishInPhase2() }
            return
        }

        for m in 0..<18 {
            let face = m / 3
            guard TwoPhaseSolver.allowed(face: face, after: lastFace) else { continue }
            phase1Path.append(m)
            searchPhase1(twist: Int(tables.twistMove[twist * 18 + m]),
                         flip: Int(tables.flipMove[flip * 18 + m]),
                         slice: Int(tables.sliceMove[slice * 18 + m]),
                         remaining: remaining - 1,
                         lastFace: face)
            phase1Path.removeLast()
        }
    }

    // MARK: - Phase 2: finish with half turns and U/D

    private func finishInPhase2() {
        let phase1Moves = phase1Path.map { Move.fromTableIndex($0) }
        // Phase 2 runs purely on coordinates, so this is the only place the search
        // touches a real cube - reading the three permutations it starts from.
        let state = cube.applying(phase1Moves)
        let cornerPerm = state.cornerPermCoordinate
        let edge8Perm = state.edge8PermCoordinate
        let slicePerm = state.slicePermCoordinate

        // Only bother with a phase 2 that would actually beat what we already have.
        let budget = min(Scrambler333.maximumLength, (best?.count ?? .max) - 1)
            - phase1Moves.count
        guard budget >= 0 else { return }

        let lastFace = phase1Path.last.map { $0 / 3 } ?? -1

        for depth in 0...budget {
            phase2Path.removeAll(keepingCapacity: true)
            if searchPhase2(cornerPerm: cornerPerm, edge8Perm: edge8Perm,
                            slicePerm: slicePerm, remaining: depth, lastFace: lastFace) {
                let solution = phase1Moves + phase2Path.map { Coordinates.phase2Moves[$0] }
                if best == nil || solution.count < best!.count { best = solution }
                return
            }
        }
    }

    private func searchPhase2(cornerPerm: Int, edge8Perm: Int, slicePerm: Int,
                              remaining: Int, lastFace: Int) -> Bool {
        let base = slicePerm * Coordinates.cornerPermCount
        let lowerBound = max(tables.cornerPrune[base + cornerPerm],
                             tables.edge8Prune[base + edge8Perm])
        if Int(lowerBound) > remaining { return false }
        if remaining == 0 { return lowerBound == 0 }

        let moveCount = Coordinates.phase2Moves.count
        for m in 0..<moveCount {
            let face = Coordinates.phase2Moves[m].face.rawValue
            guard TwoPhaseSolver.allowed(face: face, after: lastFace) else { continue }
            phase2Path.append(m)
            if searchPhase2(cornerPerm: Int(tables.cornerPermMove[cornerPerm * moveCount + m]),
                            edge8Perm: Int(tables.edge8PermMove[edge8Perm * moveCount + m]),
                            slicePerm: Int(tables.slicePermMove[slicePerm * moveCount + m]),
                            remaining: remaining - 1,
                            lastFace: face) {
                return true
            }
            phase2Path.removeLast()
        }
        return false
    }

    // MARK: - Move ordering

    /// Skips sequences that are duplicates of ones already being searched: never turn the
    /// same face twice running, and since opposite faces commute, only ever explore one of
    /// the two orders (U before D, R before L, F before B).
    static func allowed(face: Int, after last: Int) -> Bool {
        if last < 0 { return true }
        if face == last { return false }
        if face % 3 == last % 3 && face < last { return false }
        return true
    }
}
