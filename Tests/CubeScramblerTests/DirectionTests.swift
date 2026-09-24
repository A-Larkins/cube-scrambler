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

    /// The bug this pins: a prime used to animate as three quarter turns the clockwise
    /// way. It landed in the right place, so nothing looked broken until you tried to
    /// follow it with a cube in your hands and turned the layer the opposite way.
    func testEveryTurnAnimatesTheShortWayRound() {
        for face in Face.allCases {
            XCTAssertEqual(Move(face, 1).signedQuarterTurns, 1, "\(face.letter)")
            XCTAssertEqual(Move(face, 2).signedQuarterTurns, 2, "\(face.letter)2")
            XCTAssertEqual(Move(face, 3).signedQuarterTurns, -1, "\(face.letter)'")

            for amount in 1...3 {
                let move = Move(face, amount)
                let quarters = move.signedAngle / (.pi / 2)
                XCTAssertLessThanOrEqual(abs(quarters), 2.0001,
                                         "\(move.notation) sweeps \(quarters) quarter turns")
                // Still the same turn: equal to the clockwise count modulo a full turn.
                XCTAssertEqual((((-Int(quarters.rounded()) % 4) + 4) % 4), move.amount,
                               "\(move.notation) no longer lands where it should")
            }
        }
    }

    /// A prime turns the opposite way from the plain move, not merely to a different
    /// place - the two angles have to have opposite signs.
    func testPrimeSweepsOppositeToClockwise() {
        for face in Face.allCases {
            XCTAssertLessThan(Move(face, 1).signedAngle, 0, "\(face.letter) should sweep clockwise")
            XCTAssertGreaterThan(Move(face, 3).signedAngle, 0, "\(face.letter)' should sweep back")
        }
    }

    /// Stepping back through a scramble runs each move inverted, so that path has to take
    /// the short way round too.
    func testSteppingBackwardsAlsoTakesTheShortWay() {
        for move in Move.all {
            let back = move.inverse
            XCTAssertLessThanOrEqual(abs(back.signedAngle), .pi + 0.0001,
                                     "undoing \(move.notation) sweeps too far")
            XCTAssertEqual(back.signedQuarterTurns, -move.signedQuarterTurns + (move.isHalfTurn ? 4 : 0),
                           "undoing \(move.notation) is not the opposite turn")
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

    /// The exact wording for the turns people most often get backwards.
    func testSentencesReadTheWayYouTurn() {
        XCTAssertEqual(Move(.R, 1).instruction.sentence, "RIGHT side UP")
        XCTAssertEqual(Move(.R, 3).instruction.sentence, "RIGHT side DOWN")
        XCTAssertEqual(Move(.L, 1).instruction.sentence, "LEFT side DOWN")
        XCTAssertEqual(Move(.L, 3).instruction.sentence, "LEFT side UP")
        XCTAssertEqual(Move(.U, 1).instruction.sentence, "TOP layer LEFT")
        XCTAssertEqual(Move(.D, 1).instruction.sentence, "BOTTOM layer RIGHT")
        XCTAssertEqual(Move(.F, 1).instruction.sentence, "FRONT face clockwise")
        XCTAssertEqual(Move(.F, 3).instruction.sentence, "FRONT face counter-clockwise")
        XCTAssertEqual(Move(.B, 1).instruction.sentence, "BACK layer LEFT")
        XCTAssertEqual(Move(.U, 2).instruction.sentence, "TOP layer twice (180\u{00B0})")
    }

    /// The detail line has to agree with the headline's direction, never contradict it.
    func testDetailAgreesWithDirection() {
        for move in Move.all {
            let instruction = move.instruction
            guard let direction = instruction.direction else { continue }
            let detail = instruction.detail.lowercased()
            switch move.face {
            case .R, .L:
                XCTAssertTrue(detail.contains(direction == "UP" ? "rolls up" : "rolls down"), detail)
            default:
                XCTAssertTrue(detail.contains(direction.lowercased()), "\(move.notation): \(detail)")
            }
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
