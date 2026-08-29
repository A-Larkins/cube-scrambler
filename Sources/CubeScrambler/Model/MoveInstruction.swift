import Foundation

/// Plain-English description of a single turn.
///
/// The whole point of this app is that "L'" on its own does not tell you which way to
/// turn, so every instruction is stated in ONE fixed frame: as you look at the cube
/// head-on in the standard orientation (white on top, green in front). Every direction
/// here means the direction *you see it move on screen*, not "clockwise from the point
/// of view of the face", which is the ambiguity that makes the notation hard to read.
///
/// Nothing below is hand-written per move. The direction is computed from the same
/// rotation axis and sign that drives the 3D animation (`Move.rotationAxis` /
/// `Move.signedAngle`), so the sentence and the animation cannot disagree - if one is
/// wrong they are both wrong, and `DirectionTests` catches it.
struct MoveInstruction {
    let move: Move
    /// e.g. "LEFT"
    let faceName: String
    /// e.g. "front column"
    let sliceName: String
    /// e.g. "UP" - nil for half turns, where direction is meaningless.
    let direction: String?
    /// Extra orienting note for the faces you cannot see.
    let visibilityNote: String?

    var headline: String { move.prettyNotation }

    var sentence: String {
        guard let direction else {
            return "\(faceName) face - half turn, 180\u{00B0}. Direction doesn't matter."
        }
        return "\(faceName) face - turn it so the \(sliceName) slides \(direction)."
    }
}

extension Move {

    /// Unit rotation axis for this turn: the face's outward normal.
    var rotationAxis: (x: Double, y: Double, z: Double) {
        let n = face.outwardNormal
        return (Double(n.x), Double(n.y), Double(n.z))
    }

    /// Rotation angle in radians about `rotationAxis`, right-hand rule.
    ///
    /// A face turn is defined as clockwise *seen from outside that face*, which is a
    /// NEGATIVE rotation about the outward normal under the right-hand rule. Everything
    /// downstream - the SceneKit animation, the arrow, and the English sentence - reads
    /// its direction from this one expression.
    var signedAngle: Double { -Double.pi / 2 * Double(amount) }

    /// A point on this face whose motion is easy to describe, and what to call it.
    /// Chosen to be an edge centre on a row/column the viewer can actually see.
    var probe: (point: (x: Int, y: Int, z: Int), name: String) {
        switch face {
        case .U: return ((0, 1, 1), "front row of the top face")
        case .D: return ((0, -1, 1), "front row of the bottom face")
        case .R: return ((1, 0, 1), "front column of the right face")
        case .L: return ((-1, 0, 1), "front column of the left face")
        case .F: return ((0, 1, 1), "top row of the front face")
        case .B: return ((0, 1, -1), "top row of the back face")
        }
    }

    /// The probe measured from the centre of its own face, so it points across the face
    /// rather than out from the cube. The arrow is drawn centred on this direction, which
    /// is what puts it over the same row or column the sentence talks about.
    var probeOffset: (x: Double, y: Double, z: Double) {
        let n = face.outwardNormal
        let p = probe.point
        return (Double(p.x - n.x), Double(p.y - n.y), Double(p.z - n.z))
    }

    /// Which way the probe point starts moving, as a unit vector in view space.
    /// This is the tangential velocity omega x r, with omega pointing along the rotation
    /// axis with the sign of `signedAngle`.
    var probeVelocity: (x: Double, y: Double, z: Double) {
        let n = face.outwardNormal
        // A prime is the opposite rotation, but -270 degrees has the same sign as -90,
        // so the direction has to come from the effective quarter turn, not the angle.
        let sign: Double = amount == 3 ? 1 : -1
        let w = (x: Double(n.x) * sign, y: Double(n.y) * sign, z: Double(n.z) * sign)
        let r = probeOffset
        return (w.y * r.z - w.z * r.y,
                w.z * r.x - w.x * r.z,
                w.x * r.y - w.y * r.x)
    }

    private var visibilityNote: String? {
        switch face {
        case .B: return "This is the face pointing away from you."
        case .D: return "This is the face on the bottom."
        default: return nil
        }
    }

    var instruction: MoveInstruction {
        let direction: String?
        if isHalfTurn {
            direction = nil
        } else {
            let v = probeVelocity
            direction = Move.directionName(v)
        }
        return MoveInstruction(move: self,
                               faceName: face.spokenName,
                               sliceName: probe.name,
                               direction: direction,
                               visibilityNote: visibilityNote)
    }

    /// Names the dominant component of a view-space vector the way the viewer sees it.
    static func directionName(_ v: (x: Double, y: Double, z: Double)) -> String {
        let mags = [abs(v.x), abs(v.y), abs(v.z)]
        let axis = mags.firstIndex(of: mags.max()!)!
        switch axis {
        case 0: return v.x > 0 ? "RIGHT" : "LEFT"
        case 1: return v.y > 0 ? "UP" : "DOWN"
        default: return v.z > 0 ? "TOWARD YOU" : "AWAY FROM YOU"
        }
    }
}
