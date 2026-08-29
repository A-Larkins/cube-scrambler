import Foundation
@testable import CubeScrambler

/// An independent, purely geometric model of a face turn, used only by the tests.
///
/// The point of this file is to check `CubieCube`'s hand-entered permutation tables and
/// `Facelets`' sticker mapping against something derived from nothing but "rotate these
/// cubies about this axis by this angle". If Kociemba's tables, the facelet indices and
/// `Move.signedAngle` all agree with plain 3D rotation, all three are right.
enum CubeGeometry {

    typealias Vec = (x: Int, y: Int, z: Int)

    /// Rotate an integer vector by a multiple of 90 degrees about a unit integer axis,
    /// right-hand rule. Rodrigues' formula, which collapses to integer arithmetic
    /// because sin and cos are only ever -1, 0 or 1 here.
    static func rotate(_ v: Vec, axis a: Vec, quarterTurns: Int) -> Vec {
        var result = v
        for _ in 0..<(((quarterTurns % 4) + 4) % 4) {
            let cross = (x: a.y * result.z - a.z * result.y,
                         y: a.z * result.x - a.x * result.z,
                         z: a.x * result.y - a.y * result.x)
            let dot = a.x * result.x + a.y * result.y + a.z * result.z
            // theta = +90: v' = (a x v) + a(a.v)
            result = (cross.x + a.x * dot, cross.y + a.y * dot, cross.z + a.z * dot)
        }
        return result
    }

    static func face(withNormal normal: Vec) -> Face? {
        Face.allCases.first {
            let m = $0.outwardNormal
            return m.x == normal.x && m.y == normal.y && m.z == normal.z
        }
    }

    /// Applies `move` as a rotation of the affected layer, and returns the resulting
    /// sticker colours. Works for any cube size.
    static func apply(_ move: Move, to facelets: Facelets) -> Facelets {
        let n = facelets.size
        let last = n - 1
        let axis = move.face.outwardNormal
        // signedAngle is negative for a clockwise turn, so the quarter-turn count is too.
        let quarterTurns = -move.amount

        // Centred coordinates so the rotation is about the cube's middle. Doubling keeps
        // everything integral for even-sized cubes.
        func centred(_ c: Int) -> Int { 2 * c - last }
        func lattice(_ v: Int) -> Int { (v + last) / 2 }

        var colors = facelets.colors
        for cx in 0..<n {
            for cy in 0..<n {
                for cz in 0..<n {
                    guard Facelets.carries(move.face, cx: cx, cy: cy, cz: cz, size: n) else { continue }

                    let p = (x: centred(cx), y: centred(cy), z: centred(cz))
                    let np = rotate(p, axis: axis, quarterTurns: quarterTurns)
                    let dest = (x: lattice(np.x), y: lattice(np.y), z: lattice(np.z))

                    for stickerFace in Face.allCases {
                        guard Facelets.carries(stickerFace, cx: cx, cy: cy, cz: cz, size: n) else { continue }
                        let newNormal = rotate(stickerFace.outwardNormal, axis: axis,
                                               quarterTurns: quarterTurns)
                        guard let newFace = face(withNormal: newNormal) else { continue }
                        let from = Facelets.index(face: stickerFace, cx: cx, cy: cy, cz: cz, size: n)
                        let to = Facelets.index(face: newFace,
                                                cx: dest.x, cy: dest.y, cz: dest.z, size: n)
                        colors[to] = facelets.colors[from]
                    }
                }
            }
        }
        return Facelets(size: n, colors: colors)
    }
}
