import XCTest
@testable import CubeScrambler

/// The deal numbering is only worth anything if it is a bijection: every number is a real
/// cube, every cube has one number, and typing a number back in returns the same scramble.
final class DealTests: XCTestCase {

    func testTotalsAreThePublishedCounts() {
        XCTAssertEqual(Deal.total(for: .three), 43_252_003_274_489_856_000)
        XCTAssertEqual(Deal.total(for: .two), 3_674_160)
        XCTAssertEqual(Deal.total(for: .two), UInt128(Scrambler222.stateCount))
    }

    func testNumberToCubeAndBackRoundTrips() {
        var rng = SystemRandomNumberGenerator()
        for puzzle in PuzzleKind.allCases {
            let total = Deal.total(for: puzzle)
            var numbers: [UInt128] = [0, 1, total - 1, total / 2]
            numbers += (0..<200).map { _ in UInt128.random(in: 0..<total, using: &rng) }
            for number in numbers {
                let cube = Deal.cube(for: number, puzzle: puzzle)
                XCTAssertEqual(Deal.number(of: cube, puzzle: puzzle), number,
                               "deal \(Deal.formatted(number)) on the \(puzzle.displayName)")
            }
        }
    }

    /// Going the other way: a cube reached by turning it must have a number that leads
    /// straight back to that same cube.
    func testCubeToNumberAndBackRoundTrips() {
        var rng = SystemRandomNumberGenerator()
        for _ in 0..<200 {
            let cube = CubieCube.random(using: &rng)
            let number = Deal.number(of: cube, puzzle: .three)
            XCTAssertLessThan(number, Deal.total(for: .three))
            XCTAssertEqual(Deal.cube(for: number, puzzle: .three), cube)
        }
    }

    /// Every number has to land on a cube that could actually be taken apart and put back
    /// together that way - the ranges are meant to make an unreachable one impossible.
    func testEveryDealIsALegalCube() {
        var rng = SystemRandomNumberGenerator()
        for _ in 0..<300 {
            let number = UInt128.random(in: 0..<Deal.total(for: .three), using: &rng)
            let cube = Deal.cube(for: number, puzzle: .three)
            XCTAssertEqual(Set(cube.cp).count, 8)
            XCTAssertEqual(Set(cube.ep).count, 12)
            XCTAssertEqual(cube.co.reduce(0) { $0 + Int($1) } % 3, 0)
            XCTAssertEqual(cube.eo.reduce(0) { $0 + Int($1) } % 2, 0)
            XCTAssertEqual(CubieCube.parity(cube.cp), CubieCube.parity(cube.ep))
        }
    }

    func testDifferentNumbersAreDifferentCubes() {
        var rng = SystemRandomNumberGenerator()
        let numbers = (0..<300).map { _ in UInt128.random(in: 0..<Deal.total(for: .three), using: &rng) }
        let cubes = Set(numbers.map { Deal.number(of: Deal.cube(for: $0, puzzle: .three), puzzle: .three) })
        XCTAssertEqual(cubes.count, Set(numbers).count)
    }

    /// The point of the whole thing: the scramble a deal hands you really does produce
    /// that deal's position, on both puzzles.
    func testTheScrambleForADealReachesThatDeal() {
        var rng = SystemRandomNumberGenerator()
        for puzzle in PuzzleKind.allCases {
            let total = Deal.total(for: puzzle)
            let numbers = [0, total - 1] + (0..<8).map { _ in UInt128.random(in: 0..<total, using: &rng) }
            for number in numbers {
                let moves = Dealer.moves(forDeal: number, puzzle: puzzle)
                let reached = CubieCube.solved.applying(moves)
                XCTAssertEqual(Deal.number(of: reached, puzzle: puzzle), number,
                               "\(puzzle.displayName) deal \(Deal.formatted(number))")
            }
        }
    }

    /// A 2x2 deal number is the state index the solver already uses, so its scrambles stay
    /// optimal: never longer than the known worst case of 11 turns.
    func testTwoByTwoDealsStayOptimal() {
        var rng = SystemRandomNumberGenerator()
        for _ in 0..<20 {
            let number = UInt128.random(in: 0..<Deal.total(for: .two), using: &rng)
            let moves = Dealer.moves(forDeal: number, puzzle: .two)
            XCTAssertEqual(moves.count, Int(Scrambler222.distances[Int(number)]))
            XCTAssertLessThanOrEqual(moves.count, 11)
        }
    }

    func testRandomDealsAreWorthScrambling() {
        var rng = SystemRandomNumberGenerator()
        for _ in 0..<50 {
            let number = Dealer.randomDeal(puzzle: .two, using: &rng)
            XCTAssertGreaterThanOrEqual(Scrambler222.distances[Int(number)], 4)
        }
    }

    /// What is shown can be typed straight back in, commas and all.
    func testFormattingAndParsingAgree() {
        XCTAssertEqual(Deal.formatted(1_234_567), "1,234,567")
        XCTAssertEqual(Deal.formatted(43_252_003_274_489_856_000), "43,252,003,274,489,856,000")
        for number in [UInt128(0), 41, 3_674_159, 43_252_003_274_489_855_999] {
            let shown = Deal.formatted(number + 1)
            let puzzle: PuzzleKind = number < 3_674_160 ? .two : .three
            XCTAssertEqual(Deal.parse(shown, puzzle: puzzle), number, shown)
        }
    }

    func testParsingRejectsWhatIsNotADeal() {
        XCTAssertNil(Deal.parse("0", puzzle: .two))             // the numbering starts at 1
        XCTAssertNil(Deal.parse("3674161", puzzle: .two))       // one past the end
        XCTAssertNil(Deal.parse("", puzzle: .two))
        XCTAssertNil(Deal.parse("banana", puzzle: .two))
        XCTAssertEqual(Deal.parse("3,674,160", puzzle: .two), 3_674_159)
    }
}
