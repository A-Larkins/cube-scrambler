import XCTest
@testable import CubeScrambler

final class Scrambler333Tests: XCTestCase {

    // MARK: - Coordinates

    func testSolvedCubeHasZeroCoordinates() {
        let cube = CubieCube.solved
        XCTAssertEqual(cube.twist, 0)
        XCTAssertEqual(cube.flip, 0)
        XCTAssertEqual(cube.sliceCoordinate, 0)
        XCTAssertEqual(cube.cornerPermCoordinate, 0)
        XCTAssertEqual(cube.edge8PermCoordinate, 0)
        XCTAssertEqual(cube.slicePermCoordinate, 0)
        XCTAssertTrue(cube.isInPhase2Subgroup)
    }

    func testCoordinatesRoundTrip() {
        for index in stride(from: 0, to: Coordinates.twistCount, by: 7) {
            var cube = CubieCube.solved; cube.setTwist(index)
            XCTAssertEqual(cube.twist, index)
        }
        for index in stride(from: 0, to: Coordinates.flipCount, by: 7) {
            var cube = CubieCube.solved; cube.setFlip(index)
            XCTAssertEqual(cube.flip, index)
        }
        for index in 0..<Coordinates.sliceCount {
            var cube = CubieCube.solved; cube.setSliceCoordinate(index)
            XCTAssertEqual(cube.sliceCoordinate, index)
        }
        for index in stride(from: 0, to: Coordinates.cornerPermCount, by: 97) {
            var cube = CubieCube.solved; cube.setCornerPermCoordinate(index)
            XCTAssertEqual(cube.cornerPermCoordinate, index)
        }
        for index in stride(from: 0, to: Coordinates.edge8PermCount, by: 97) {
            var cube = CubieCube.solved; cube.setEdge8PermCoordinate(index)
            XCTAssertEqual(cube.edge8PermCoordinate, index)
        }
        for index in 0..<Coordinates.slicePermCount {
            var cube = CubieCube.solved; cube.setSlicePermCoordinate(index)
            XCTAssertEqual(cube.slicePermCoordinate, index)
        }
    }

    /// A coordinate is only usable if it moves the same way whatever the rest of the cube
    /// is doing - that independence is the whole basis of the lookup tables.
    func testMoveTablesAgreeWithRealCubes() {
        var rng = SystemRandomNumberGenerator()
        let tables = Tables333.shared
        for _ in 0..<200 {
            let cube = CubieCube.random(using: &rng)
            for (m, move) in Move.all.enumerated() {
                let turned = cube.applying(move)
                XCTAssertEqual(Int(tables.twistMove[cube.twist * 18 + m]), turned.twist)
                XCTAssertEqual(Int(tables.flipMove[cube.flip * 18 + m]), turned.flip)
                XCTAssertEqual(Int(tables.sliceMove[cube.sliceCoordinate * 18 + m]),
                               turned.sliceCoordinate)
            }
        }
    }

    func testPhase2MoveTablesAgreeWithRealCubes() {
        var rng = SystemRandomNumberGenerator()
        let tables = Tables333.shared
        let count = Coordinates.phase2Moves.count
        for _ in 0..<200 {
            // A random member of the phase-2 subgroup: scramble a solved cube with
            // phase-2 moves only.
            var cube = CubieCube.solved
            for _ in 0..<20 { cube = cube.applying(Coordinates.phase2Moves.randomElement(using: &rng)!) }
            for (m, move) in Coordinates.phase2Moves.enumerated() {
                let turned = cube.applying(move)
                XCTAssertEqual(Int(tables.cornerPermMove[cube.cornerPermCoordinate * count + m]),
                               turned.cornerPermCoordinate)
                XCTAssertEqual(Int(tables.edge8PermMove[cube.edge8PermCoordinate * count + m]),
                               turned.edge8PermCoordinate)
                XCTAssertEqual(Int(tables.slicePermMove[cube.slicePermCoordinate * count + m]),
                               turned.slicePermCoordinate)
            }
        }
    }

    // MARK: - Pruning tables

    func testPruningTablesAreZeroOnlyAtTheGoal() {
        let tables = Tables333.shared
        XCTAssertEqual(tables.sliceTwistPrune[0], 0)
        XCTAssertEqual(tables.sliceFlipPrune[0], 0)
        XCTAssertEqual(tables.cornerPrune[0], 0)
        XCTAssertEqual(tables.edge8Prune[0], 0)
        XCTAssertEqual(tables.sliceTwistPrune.filter { $0 == 0 }.count, 1)
        XCTAssertEqual(tables.sliceFlipPrune.filter { $0 == 0 }.count, 1)
        XCTAssertEqual(tables.cornerPrune.filter { $0 == 0 }.count, 1)
        XCTAssertEqual(tables.edge8Prune.filter { $0 == 0 }.count, 1)
    }

    /// Phase 1 never needs more than 12 moves and phase 2 never more than 18; if a table
    /// held a larger value the search bounds would be wrong.
    func testPruningDepthsAreWithinKnownBounds() {
        let tables = Tables333.shared
        let reachable: (UInt8) -> Bool = { $0 != Tables333.unreachable }
        XCTAssertLessThanOrEqual(tables.sliceTwistPrune.filter(reachable).max() ?? 0, 12)
        XCTAssertLessThanOrEqual(tables.sliceFlipPrune.filter(reachable).max() ?? 0, 12)
        XCTAssertLessThanOrEqual(tables.cornerPrune.filter(reachable).max() ?? 0, 18)
        XCTAssertLessThanOrEqual(tables.edge8Prune.filter(reachable).max() ?? 0, 18)
    }

    // MARK: - Solving and scrambling

    func testSolvedCubeNeedsNoMoves() {
        XCTAssertEqual(Scrambler333.solve(CubieCube.solved), [])
    }

    func testSolutionsSolve() {
        var rng = SystemRandomNumberGenerator()
        for _ in 0..<30 {
            let cube = CubieCube.random(using: &rng)
            let solution = Scrambler333.solve(cube)
            XCTAssertTrue(cube.applying(solution).isSolved, "failed on \(solution.notation)")
            XCTAssertLessThanOrEqual(solution.count, Scrambler333.maximumLength)
        }
    }

    /// The test that proves the whole feature: the scramble must land the cube on exactly
    /// the random state it was generated for.
    func testScrambleReachesItsTargetState() {
        var rng = SystemRandomNumberGenerator()
        for _ in 0..<30 {
            let target = CubieCube.random(using: &rng)
            let scramble = Scrambler333.solve(target).inverted
            XCTAssertEqual(CubieCube.solved.applying(scramble), target)
        }
    }

    func testScramblesLookLikeCompetitionScrambles() {
        var rng = SystemRandomNumberGenerator()
        for _ in 0..<20 {
            let scramble = Scrambler333.scramble(using: &rng)
            XCTAssertGreaterThanOrEqual(scramble.count, 15)
            XCTAssertLessThanOrEqual(scramble.count, Scrambler333.maximumLength)
            for (a, b) in zip(scramble, scramble.dropFirst()) {
                XCTAssertNotEqual(a.face, b.face, "redundant pair in \(scramble.notation)")
            }
            XCTAssertFalse(CubieCube.solved.applying(scramble).isSolved)
        }
    }
}
