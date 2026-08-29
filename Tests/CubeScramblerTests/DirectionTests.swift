import XCTest
@testable import CubeScrambler

/// The app's whole reason to exist is that "L'" doesn't tell you which way to turn.
/// These tests pin the English sentence to the actual motion of the cube, so a wrong
/// instruction is a red build rather than something you discover with a cube in hand.
final class DirectionTests: XCTestCase {

    /// What each clockwise quarter turn should read as, in the fixed front-on frame.
    /// Written out independently of the code that generates it.
    private let expected: [Face: String] = [
        .U: "LEFT",   // the front row of the top slides left
        .D: "RIGHT",
        .R: "UP",     // the front column of the right face rises
        .L: "DOWN",
        .F: "RIGHT",
        .B: "LEFT"
    ]

    func testClockwiseDirectionsMatchTheWrittenTable() {
        for (face, direction) in expected {
            XCTAssertEqual(Move(face, 1).instruction.direction, direction, face.letter)
        }
    }

    func testPrimeIsAlwaysTheOppositeDirection() {
        let opposite = ["LEFT": "RIGHT", "RIGHT": "LEFT", "UP": "DOWN", "DOWN": "UP"]
        for face in Face.allCases {
            let cw = Move(face, 1).instruction.direction!
            XCTAssertEqual(Move(face, 3).instruction.direction, opposite[cw], "\(face.letter)'")
        }
    }

    func testHalfTurnsClaimNoDirection() {
        for face in Face.allCases {
            XCTAssertNil(Move(face, 2).instruction.direction)
            XCTAssertTrue(Move(face, 2).instruction.sentence.contains("180"))
        }
    }

    /// The strong version: rotate the probe sticker the way the animation will rotate it,
    /// and check it really travels the way the sentence says.
    func testProbeStickerActuallyTravelsTheStatedWay() {
        for face in Face.allCases {
            let move = Move(face, 1)
            let instruction = move.instruction
            guard let direction = instruction.direction else { continue }

            // Probe point in centred coordinates, and where the turn sends it.
            let start = probePoint(for: face)
            let end = CubeGeometry.rotate(start, axis: face.outwardNormal, quarterTurns: -1)
            let delta = (x: end.x - start.x, y: end.y - start.y, z: end.z - start.z)

            switch direction {
            case "LEFT":  XCTAssertLessThan(delta.x, 0, "\(move.notation) should go left")
            case "RIGHT": XCTAssertGreaterThan(delta.x, 0, "\(move.notation) should go right")
            case "UP":    XCTAssertGreaterThan(delta.y, 0, "\(move.notation) should go up")
            case "DOWN":  XCTAssertLessThan(delta.y, 0, "\(move.notation) should go down")
            default:      XCTFail("unexpected direction \(direction) for \(move.notation)")
            }
        }
    }

    /// Mirrors the private probe in `Move.instruction`: the edge centre on the row or
    /// column the sentence names.
    private func probePoint(for face: Face) -> CubeGeometry.Vec {
        switch face {
        case .U: return (0, 1, 1)
        case .D: return (0, -1, 1)
        case .R: return (1, 0, 1)
        case .L: return (-1, 0, 1)
        case .F: return (0, 1, 1)
        case .B: return (0, 1, -1)
        }
    }

    func testEverySentenceNamesItsFace() {
        for move in Move.all {
            XCTAssertTrue(move.instruction.sentence.hasPrefix(move.face.spokenName),
                          move.instruction.sentence)
        }
    }
}

/// Ties the drawn arrow to the written sentence.
///
/// The two are generated separately - one is 3D geometry in the face's own plane, the
/// other is English - so this is where they get checked against each other. If the arrow
/// ever points somewhere the sentence does not, this fails.
@MainActor
final class ArrowDirectionTests: XCTestCase {

    func testArrowTravelsTheWayTheSentenceSays() {
        for face in Face.allCases {
            for amount in [1, 3] {
                let move = Move(face, amount)
                guard let stated = move.instruction.direction else { continue }

                // Direction the arrow sweeps, in the face's own drawing plane.
                let angle = CubeSceneController.probeAngle(for: move) * .pi / 180
                let sign: Float = amount == 3 ? 1 : -1
                let tangent = SIMD3<Float>(sign * -sin(Float(angle)), sign * cos(Float(angle)), 0)

                // Back out to world space through the same rotation that orients the arrow.
                let world = CubeSceneController.arrowOrientation(for: face).act(tangent)
                let drawn = Move.directionName((Double(world.x), Double(world.y), Double(world.z)))

                XCTAssertEqual(drawn, stated,
                               "\(move.notation): arrow points \(drawn), sentence says \(stated)")
            }
        }
    }

    /// And the arc really does sit over the row the sentence names, not somewhere else on
    /// the face - that was the point of centring it on the probe.
    func testArrowSitsOverTheRowTheSentenceNames() {
        for move in Move.all {
            let angle = CubeSceneController.probeAngle(for: move) * .pi / 180
            let onFace = SIMD3<Float>(cos(Float(angle)), sin(Float(angle)), 0)
            let world = CubeSceneController.arrowOrientation(for: move.face).act(onFace)
            let offset = move.probeOffset
            let length = (offset.x * offset.x + offset.y * offset.y + offset.z * offset.z).squareRoot()
            let dot = Double(world.x) * offset.x / length
                + Double(world.y) * offset.y / length
                + Double(world.z) * offset.z / length
            XCTAssertGreaterThan(dot, 0.99, "\(move.notation) arc is not centred on its probe")
        }
    }
}
