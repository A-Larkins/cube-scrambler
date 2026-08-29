import XCTest
@testable import CubeScrambler

final class Scrambler222Tests: XCTestCase {

    /// Built once for the whole suite - the BFS is the expensive part.
    private static let table = Scrambler222.buildDistances()

    func testEveryStateIsReachable() {
        let table = Self.table
        XCTAssertEqual(table.count, 3_674_160)
        XCTAssertFalse(table.contains(Scrambler222.unvisited), "some state was never reached")
    }

    /// The exact number of 2x2 positions at each distance is a published, checkable fact.
    /// If the move tables or the coordinate encoding were subtly wrong, the search would
    /// still terminate but these counts would not come out.
    func testDepthHistogramMatchesKnownValues() {
        let expected = [1, 9, 54, 321, 1_847, 9_992, 50_136, 227_536,
                        870_072, 1_887_748, 623_800, 2_644]
        var histogram = [Int](repeating: 0, count: 12)
        for d in Self.table { histogram[Int(d)] += 1 }
        XCTAssertEqual(histogram, expected)
        XCTAssertEqual(expected.reduce(0, +), Scrambler222.stateCount)
    }

    func testSolutionsActuallySolve() {
        var rng = SystemRandomNumberGenerator()
        for _ in 0..<200 {
            let state = Int.random(in: 0..<Scrambler222.stateCount, using: &rng)
            let solution = Scrambler222.solve(state: state, distances: Self.table)
            XCTAssertEqual(solution.count, Int(Self.table[state]), "solution should be optimal")
            XCTAssertLessThanOrEqual(solution.count, 11, "God's number for 2x2 is 11")
        }
    }

    /// The scramble must genuinely produce the state it claims: apply it to a solved
    /// cube and the result has to be exactly the state the solver started from.
    func testScrambleReachesItsTargetState() {
        var rng = SystemRandomNumberGenerator()
        for _ in 0..<300 {
            let target = Int.random(in: 0..<Scrambler222.stateCount, using: &rng)
            let scramble = Scrambler222.solve(state: target, distances: Self.table).inverted
            XCTAssertEqual(Scrambler222.stateIndex(after: scramble), target)
        }
    }

    func testGeneratedScramblesAreSaneAndUseOnlyURF() {
        var rng = SystemRandomNumberGenerator()
        for _ in 0..<200 {
            let scramble = Scrambler222.scramble(using: &rng)
            XCTAssertGreaterThanOrEqual(scramble.count, 4)
            XCTAssertLessThanOrEqual(scramble.count, 11)
            for move in scramble {
                XCTAssertTrue([Face.U, .R, .F].contains(move.face), move.notation)
            }
            XCTAssertFalse(CubieCube.solved.applying(scramble).isSolved)
        }
    }

    func testNoTwoConsecutiveMovesShareAFace() {
        var rng = SystemRandomNumberGenerator()
        for _ in 0..<200 {
            let scramble = Scrambler222.scramble(using: &rng)
            for (a, b) in zip(scramble, scramble.dropFirst()) {
                XCTAssertNotEqual(a.face, b.face, "redundant pair in \(scramble.notation)")
            }
        }
    }
}
