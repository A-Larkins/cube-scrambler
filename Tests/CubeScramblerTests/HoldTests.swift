import XCTest
@testable import CubeScrambler

final class HoldTests: XCTestCase {

    /// A hold is only a way of picking the cube up, so every corner it paints has to be a
    /// corner that exists on a real cube, with its colours going round the same way. A
    /// wrong hold - say red and orange swapped - gives the mirror image of every corner,
    /// which no amount of turning a physical cube can match.
    func testEveryHoldIsARealCube() {
        let reference = Hold.greenFrontWhiteUp
        func corners(_ hold: Hold) -> Set<[StickerColor]> {
            Set(Facelets.cornerFacelet.map { stickers in
                canonical(stickers.map { hold.color(of: Facelets.homeFace(of: $0)) })
            })
        }
        for hold in Hold.allCases {
            XCTAssertEqual(corners(hold), corners(reference), hold.displayName)
        }
    }

    func testBlueFrontWhiteDown() {
        let hold = Hold.blueFrontWhiteDown
        XCTAssertEqual(hold.color(of: .F), .blue)
        XCTAssertEqual(hold.color(of: .D), .white)
        XCTAssertEqual(hold.color(of: .U), .yellow)
        XCTAssertEqual(hold.color(of: .R), .red)
        XCTAssertEqual(Set(Face.allCases.map(hold.color(of:))).count, 6)
    }

    func testBlueFrontWhiteDownIsTheDefault() {
        XCTAssertEqual(Hold.standard, .blueFrontWhiteDown)
    }

    /// Rotates a cyclic triple so its smallest colour comes first, keeping the order.
    private func canonical(_ colors: [StickerColor]) -> [StickerColor] {
        let order = StickerColor.allCases
        let start = colors.indices.min { order.firstIndex(of: colors[$0])! < order.firstIndex(of: colors[$1])! }!
        return (0..<colors.count).map { colors[(start + $0) % colors.count] }
    }
}
