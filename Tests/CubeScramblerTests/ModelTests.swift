import XCTest
@testable import CubeScrambler

final class ModelTests: XCTestCase {

    // MARK: - Move algebra

    func testQuarterTurnsCycleAfterFour() {
        for face in Face.allCases {
            var cube = CubieCube.solved
            for _ in 0..<4 { cube = cube.applying(Move(face, 1)) }
            XCTAssertTrue(cube.isSolved, "\(face.letter) applied four times should solve")
        }
    }

    func testMoveThenInverseIsIdentity() {
        for move in Move.all {
            let cube = CubieCube.solved.applying(move).applying(move.inverse)
            XCTAssertTrue(cube.isSolved, "\(move.notation) then \(move.inverse.notation)")
        }
    }

    func testSexyMoveHasOrderSix() {
        let sexy = Move.parse("R U R' U'")
        var cube = CubieCube.solved
        for i in 1...6 {
            cube = cube.applying(sexy)
            XCTAssertEqual(cube.isSolved, i == 6, "(R U R' U')^\(i)")
        }
    }

    func testNotationRoundTrips() {
        let text = "R U2 F' L D2 B' R' U L2"
        XCTAssertEqual(Move.parse(text).notation, text)
    }

    func testInvertedSequenceUndoesIt() {
        let moves = Move.parse("R U2 F' L D2 B' R' U L2")
        XCTAssertTrue(CubieCube.solved.applying(moves).applying(moves.inverted).isSolved)
    }

    // MARK: - The cross-check that validates everything at once

    /// `CubieCube`'s permutation tables were entered by hand and `Facelets` maps them to
    /// screen positions by hand. Rotating the stickers geometrically uses neither. If
    /// they agree on all 18 moves, the tables, the sticker mapping and the sign of
    /// `Move.signedAngle` are all correct together.
    func testCubieTablesMatchPureGeometry() {
        for move in Move.all {
            let viaTables = Facelets.from(cube: CubieCube.solved.applying(move))
            let viaGeometry = CubeGeometry.apply(move, to: .solved(size: 3))
            XCTAssertEqual(viaTables, viaGeometry, "3x3 \(move.notation)")
        }
    }

    func testCornerOnlyFaceletsMatchGeometryOnTwoByTwo() {
        for move in Move.all {
            let viaTables = Facelets.fromCorners(cube: CubieCube.solved.applying(move))
            let viaGeometry = CubeGeometry.apply(move, to: .solved(size: 2))
            XCTAssertEqual(viaTables, viaGeometry, "2x2 \(move.notation)")
        }
    }

    func testRandomSequenceStaysConsistentBetweenModels() {
        var rng = SystemRandomNumberGenerator()
        for _ in 0..<50 {
            let moves = (0..<15).map { _ in Move.all.randomElement(using: &rng)! }
            var facelets = Facelets.solved(size: 3)
            for move in moves { facelets = CubeGeometry.apply(move, to: facelets) }
            XCTAssertEqual(Facelets.from(cube: CubieCube.solved.applying(moves)), facelets,
                           moves.notation)
        }
    }

    // MARK: - Random state

    func testRandomStatesAreWellFormed() {
        var rng = SystemRandomNumberGenerator()
        for _ in 0..<500 {
            let cube = CubieCube.random(using: &rng)
            XCTAssertEqual(Set(cube.cp).count, 8)
            XCTAssertEqual(Set(cube.ep).count, 12)
            XCTAssertEqual(cube.co.reduce(0) { $0 + Int($1) } % 3, 0, "total twist")
            XCTAssertEqual(cube.eo.reduce(0) { $0 + Int($1) } % 2, 0, "total flip")
            XCTAssertEqual(CubieCube.parity(cube.cp), CubieCube.parity(cube.ep), "parity")
        }
    }
}
