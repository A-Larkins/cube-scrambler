import Foundation
// SceneKit predates strict concurrency and marks nothing Sendable, so hopping an SCNNode
// back to the main actor after an action finishes trips the checker. Everything here runs
// on the main actor already; @preconcurrency says so rather than restructuring around it.
@preconcurrency import SceneKit
import AppKit

/// Builds and drives the 3D cube.
///
/// Cubies never actually change position. A turn is animated by hanging the moving layer
/// off a temporary pivot node and rotating that; when the animation ends the cubies go
/// back where they were and every sticker is simply recoloured from the new cube state.
/// The result is pixel-identical to permanently moving them, and it means the scene can
/// never drift out of step with the model - there is no accumulated transform to get wrong.
@MainActor
final class CubeSceneController {

    let scene = SCNScene()

    private let cubeRoot = SCNNode()
    private let yawNode = SCNNode()
    private let pitchNode = SCNNode()
    private let cameraNode = SCNNode()
    private var arrowNode: SCNNode?

    /// Every drawn cubie, with the lattice position it occupies.
    private var cubies: [(node: SCNNode, cx: Int, cy: Int, cz: Int)] = []
    private var size = 3
    /// Which colour each face is painted. Set before `update(facelets:)`.
    var hold: Hold = .standard

    private let spacing: CGFloat = 1.03
    private var azimuth: Double = Defaults.azimuth      // continuous, so swings take the short way
    private var pitch: Double = Defaults.elevation

    enum Defaults {
        static let azimuth: Double = 30
        static let elevation: Double = 20
        static let turnDuration: TimeInterval = 0.62
        static let swingDuration: TimeInterval = 0.38
        /// How long the arrow sits still before the turn starts.
        static let arrowHold: TimeInterval = 0.28
        /// How dark the still layers go while a turn is only being shown, not made.
        /// Lighter than during the turn, so the rest of the cube stays readable.
        static let previewDim: CGFloat = 0.55
        static let turnDim: CGFloat = 0.30
    }

    init() {
        scene.background.contents = NSColor.clear
        scene.rootNode.addChildNode(cubeRoot)

        let camera = SCNCamera()
        camera.usesOrthographicProjection = true
        camera.orthographicScale = 2.9
        camera.zNear = 0.1
        camera.zFar = 100
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(0, 0, 12)

        // Two nested nodes rather than euler angles on one, so yaw and pitch stay
        // independent and a swing is just two numbers.
        pitchNode.addChildNode(cameraNode)
        yawNode.addChildNode(pitchNode)
        scene.rootNode.addChildNode(yawNode)
        applyCamera(animated: false)

        let key = SCNNode()
        key.light = SCNLight()
        key.light?.type = .directional
        key.light?.intensity = 620
        key.eulerAngles = SCNVector3(-Float.pi / 5, Float.pi / 5, 0)
        cameraNode.addChildNode(key)

        let fill = SCNNode()
        fill.light = SCNLight()
        fill.light?.type = .ambient
        fill.light?.intensity = 620
        scene.rootNode.addChildNode(fill)
    }

    // MARK: - Building

    func build(size n: Int) {
        guard n != size || cubies.isEmpty else { return }
        size = n
        cubies.forEach { $0.node.removeFromParentNode() }
        cubies.removeAll()

        let offset = Double(n - 1) / 2
        for cx in 0..<n {
            for cy in 0..<n {
                for cz in 0..<n {
                    guard Facelets.isVisible(cx: cx, cy: cy, cz: cz, size: n) else { continue }
                    let box = SCNBox(width: spacing * 0.96, height: spacing * 0.96,
                                     length: spacing * 0.96, chamferRadius: spacing * 0.11)
                    // One material per side so each sticker can be coloured on its own.
                    box.materials = (0..<6).map { _ in CubeSceneController.plastic() }
                    let node = SCNNode(geometry: box)
                    node.position = SCNVector3((Double(cx) - offset) * Double(spacing),
                                               (Double(cy) - offset) * Double(spacing),
                                               (Double(cz) - offset) * Double(spacing))
                    cubeRoot.addChildNode(node)
                    cubies.append((node, cx, cy, cz))
                }
            }
        }
    }

    /// SCNBox material order is front, right, back, left, top, bottom.
    private static let boxFaceOrder: [Face] = [.F, .R, .B, .L, .U, .D]

    func update(facelets: Facelets) {
        guard facelets.size == size else { return }
        for cubie in cubies {
            guard let materials = cubie.node.geometry?.materials else { continue }
            for (slot, face) in CubeSceneController.boxFaceOrder.enumerated() {
                let showsSticker = Facelets.carries(face, cx: cubie.cx, cy: cubie.cy,
                                                    cz: cubie.cz, size: size)
                let color: NSColor
                if showsSticker {
                    let index = Facelets.index(face: face, cx: cubie.cx, cy: cubie.cy,
                                               cz: cubie.cz, size: size)
                    color = Palette.stickerColor(facelets[index], hold: hold)
                } else {
                    color = Palette.bodyColor
                }
                materials[slot].diffuse.contents = color
            }
        }
    }

    private static func plastic() -> SCNMaterial {
        let material = SCNMaterial()
        material.lightingModel = .physicallyBased
        material.roughness.contents = 0.42
        material.metalness.contents = 0.0
        return material
    }

    // MARK: - Camera

    /// Where to stand to see a given face turn. Each viewpoint is off-axis on purpose:
    /// dead-on loses the depth cues that tell you which way a face is rotating.
    static func viewpoint(for face: Face) -> (azimuth: Double, elevation: Double) {
        switch face {
        case .F: return (30, 20)
        case .R: return (62, 18)
        case .U: return (30, 56)
        case .L: return (-62, 18)
        case .D: return (30, -56)
        case .B: return (150, 18)
        }
    }

    func swingCamera(to face: Face, animated: Bool = true) {
        let target = CubeSceneController.viewpoint(for: face)
        // Keep the azimuth continuous and take whichever way round is shorter, so the
        // cube never spins the long way to get somewhere close by.
        var delta = target.azimuth - azimuth.truncatingRemainder(dividingBy: 360)
        while delta > 180 { delta -= 360 }
        while delta < -180 { delta += 360 }
        azimuth += delta
        pitch = target.elevation
        applyCamera(animated: animated)
    }

    func resetCamera(animated: Bool = true) {
        var delta = Defaults.azimuth - azimuth.truncatingRemainder(dividingBy: 360)
        while delta > 180 { delta -= 360 }
        while delta < -180 { delta += 360 }
        azimuth += delta
        pitch = Defaults.elevation
        applyCamera(animated: animated)
    }

    /// Free look, from a drag in the view.
    func nudgeCamera(azimuthDelta: Double, elevationDelta: Double) {
        azimuth += azimuthDelta
        pitch = max(-88, min(88, pitch + elevationDelta))
        applyCamera(animated: false)
    }

    private func applyCamera(animated: Bool) {
        let apply = {
            self.yawNode.eulerAngles = SCNVector3(0, Float(self.azimuth * .pi / 180), 0)
            self.pitchNode.eulerAngles = SCNVector3(Float(-self.pitch * .pi / 180), 0, 0)
        }
        guard animated else { apply(); return }
        SCNTransaction.begin()
        SCNTransaction.animationDuration = Defaults.swingDuration
        SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        apply()
        SCNTransaction.commit()
    }

    // MARK: - Turning

    /// Runs one whole move: swing round to the face, show the arrow, hold for a beat so
    /// you can read it, then turn. The pause matters - an arrow that appears and moves in
    /// the same instant tells you nothing.
    ///
    /// `forward` false runs the same turn backwards, for stepping back through a scramble.
    func perform(move: Move,
                 forward: Bool,
                 resulting facelets: Facelets,
                 swingCamera swing: Bool,
                 completion: @escaping () -> Void) {
        let effective = forward ? move : move.inverse
        highlight(layer: move.face, on: true)
        showArrow(for: effective)
        if swing { swingCamera(to: move.face) }

        let lead = (swing ? Defaults.swingDuration : 0) + Defaults.arrowHold
        DispatchQueue.main.asyncAfter(deadline: .now() + lead) { [weak self] in
            self?.runTurn(move: move, effective: effective, resulting: facelets,
                          completion: completion)
        }
    }

    /// Shows the turn that is coming up without making it: the arrow on its face, the
    /// layer lit, and the camera round to where it can be seen. Nil clears all of that.
    /// This is what a click on a move in the scramble lands on.
    func showPreview(of move: Move?, swingCamera swing: Bool) {
        cubies.forEach { cubie in
            cubie.node.geometry?.materials.forEach { $0.multiply.contents = NSColor.white }
        }
        guard let move else {
            hideArrow()
            return
        }
        highlight(layer: move.face, on: true, dim: Defaults.previewDim)
        showArrow(for: move)
        if swing { swingCamera(to: move.face) }
    }

    private func runTurn(move: Move,
                         effective: Move,
                         resulting facelets: Facelets,
                         completion: @escaping () -> Void) {
        let pivot = SCNNode()
        cubeRoot.addChildNode(pivot)
        let moving = cubies.filter {
            Facelets.carries(move.face, cx: $0.cx, cy: $0.cy, cz: $0.cz, size: size)
        }
        // The pivot sits at the origin with no transform of its own, so re-parenting into
        // it leaves every cubie exactly where it was on screen.
        for cubie in moving { pivot.addChildNode(cubie.node) }

        let axis = effective.rotationAxis
        let rotation = SCNAction.rotate(by: CGFloat(effective.signedAngle),
                                        around: SCNVector3(axis.x, axis.y, axis.z),
                                        duration: Defaults.turnDuration)
        rotation.timingMode = .easeInEaseOut

        pivot.runAction(rotation) { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                for cubie in moving {
                    cubie.node.removeFromParentNode()
                    cubie.node.transform = SCNMatrix4Identity
                    cubie.node.position = self.homePosition(cx: cubie.cx, cy: cubie.cy, cz: cubie.cz)
                    self.cubeRoot.addChildNode(cubie.node)
                }
                pivot.removeFromParentNode()
                self.update(facelets: facelets)
                self.highlight(layer: move.face, on: false)
                self.hideArrow()
                completion()
            }
        }
    }

    private func homePosition(cx: Int, cy: Int, cz: Int) -> SCNVector3 {
        let offset = Double(size - 1) / 2
        return SCNVector3((Double(cx) - offset) * Double(spacing),
                          (Double(cy) - offset) * Double(spacing),
                          (Double(cz) - offset) * Double(spacing))
    }

    /// Dims everything that is not turning, so you cannot grab the wrong layer.
    ///
    /// Undimming multiplies by white rather than clearing `contents`: the property is
    /// typed `Any?`, so assigning an `NSColor?` that happens to be nil stores the wrapped
    /// optional instead of removing the shade, and the cube stays dark for good.
    private func highlight(layer face: Face, on: Bool, dim: CGFloat = Defaults.turnDim) {
        for cubie in cubies {
            let moving = Facelets.carries(face, cx: cubie.cx, cy: cubie.cy, cz: cubie.cz, size: size)
            let shade = (on && !moving) ? NSColor(white: dim, alpha: 1) : NSColor.white
            cubie.node.geometry?.materials.forEach { $0.multiply.contents = shade }
        }
    }

    // MARK: - The direction arrow

    /// A curved arrow lying on the face that is about to turn, pointing the way it goes.
    /// This is the cue that "L\u{2032}" alone cannot give you.
    func showArrow(for move: Move) {
        hideArrow()
        let half = Double(size) * Double(spacing) / 2
        let radius = half * 0.56
        let thickness = half * 0.18

        let container = SCNNode()
        // Local +Z is the face's outward normal, so a clockwise sweep drawn in this plane
        // is exactly the way the cube is about to turn.
        container.simdOrientation = CubeSceneController.arrowOrientation(for: move.face)
        let normal = move.face.outwardNormal
        let standoff = half + 0.18
        container.position = SCNVector3(Double(normal.x) * standoff,
                                        Double(normal.y) * standoff,
                                        Double(normal.z) * standoff)

        // A dark halo underneath, so the arrow reads on white and yellow stickers as
        // clearly as it does on the dark ones.
        container.addChildNode(arrow(move: move, radius: radius, thickness: thickness,
                                     inflate: thickness * 0.20,
                                     color: NSColor(calibratedWhite: 0.05, alpha: 1),
                                     depth: -0.02))
        container.addChildNode(arrow(move: move, radius: radius, thickness: thickness,
                                     inflate: 0, color: Palette.accentColor, depth: 0))

        cubeRoot.addChildNode(container)
        arrowNode = container
    }

    func hideArrow() {
        arrowNode?.removeFromParentNode()
        arrowNode = nil
    }

    /// One curved arrow: a band swept along an arc, with a head on the leading end (both
    /// ends for a half turn, which can be made either way round).
    private func arrow(move: Move, radius: Double, thickness: Double,
                       inflate: Double, color: NSColor, depth: Double) -> SCNNode {
        let counterClockwise = move.amount == 3
        let sign: Double = counterClockwise ? 1 : -1
        let sweep = move.isHalfTurn ? 152.0 : 120.0
        // Centre the arc on the row or column the written instruction names, so the head
        // lands exactly where the sentence says the stickers are going. Without this the
        // arc sits at whatever local angle zero happens to be, which is a different - and
        // often hidden - part of every face.
        let centre = CubeSceneController.probeAngle(for: move)
        // Grow the halo along the arc as well as across it, or the ends would show through.
        let extra = inflate / radius * 180 / .pi
        let width = thickness + 2 * inflate
        let headAngle = 27.0

        let tail = centre - sign * (sweep / 2 + extra)
        let tip = centre + sign * (sweep / 2 + extra)
        let bandStart = move.isHalfTurn ? tail + sign * headAngle : tail
        let bandEnd = tip - sign * headAngle

        let node = SCNNode()
        node.addChildNode(band(from: bandStart, to: bandEnd, radius: radius,
                               width: width, color: color, depth: depth))
        // The head takes only half the halo's inflation. At full inflation the dark
        // cone swallows the amber one and the arrow reads as a black arrowhead.
        let headWidth = thickness + inflate
        node.addChildNode(head(at: tip, radius: radius, width: headWidth,
                               increasing: counterClockwise, color: color, depth: depth))
        if move.isHalfTurn {
            node.addChildNode(head(at: tail, radius: radius, width: headWidth,
                                   increasing: !counterClockwise, color: color, depth: depth))
        }
        return node
    }

    /// The arc itself, as an explicit polygon. Built point by point rather than with
    /// `NSBezierPath.appendArc`, whose flattening collapsed the band to a sliver.
    private func band(from startDegrees: Double, to endDegrees: Double,
                      radius: Double, width: Double, color: NSColor, depth: Double) -> SCNNode {
        let steps = 48
        let path = NSBezierPath()
        func point(_ degrees: Double, _ r: Double) -> CGPoint {
            let radians = degrees * .pi / 180
            return CGPoint(x: r * cos(radians), y: r * sin(radians))
        }
        for step in 0...steps {
            let degrees = startDegrees + (endDegrees - startDegrees) * Double(step) / Double(steps)
            let corner = point(degrees, radius + width / 2)
            step == 0 ? path.move(to: corner) : path.line(to: corner)
        }
        for step in 0...steps {
            let degrees = endDegrees + (startDegrees - endDegrees) * Double(step) / Double(steps)
            path.line(to: point(degrees, radius - width / 2))
        }
        path.close()

        let shape = SCNShape(path: path, extrusionDepth: 0.05)
        shape.materials = [CubeSceneController.arrowMaterial(color)]
        let node = SCNNode(geometry: shape)
        node.position = SCNVector3(0, 0, depth)
        return node
    }

    private func head(at degrees: Double, radius: Double, width: Double,
                      increasing: Bool, color: NSColor, depth: Double) -> SCNNode {
        let cone = SCNCone(topRadius: 0, bottomRadius: CGFloat(width * 0.95),
                           height: CGFloat(width * 1.75))
        cone.materials = [CubeSceneController.arrowMaterial(color)]
        let node = SCNNode(geometry: cone)
        let radians = degrees * .pi / 180
        node.position = SCNVector3(radius * cos(radians), radius * sin(radians), depth)
        // A cone points along its own +Y; spinning it by the arc angle lines +Y up with
        // the tangent, plus half a turn when the arrow runs the other way round.
        node.eulerAngles = SCNVector3(0, 0, Float(increasing ? radians : radians + .pi))
        return node
    }

    private static func arrowMaterial(_ color: NSColor) -> SCNMaterial {
        let material = SCNMaterial()
        material.lightingModel = .constant
        material.diffuse.contents = color
        material.emission.contents = color
        material.isDoubleSided = true
        // Read depth so the arrow is properly hidden behind the cube rather than
        // floating over the near face when it is on a side you cannot see.
        material.writesToDepthBuffer = true
        material.readsFromDepthBuffer = true
        return material
    }

    /// Where the instruction's probe row sits, as an angle in the face's own drawing
    /// plane. Measured by taking the probe direction back through the same rotation that
    /// orients the arrow, so the two cannot disagree.
    static func probeAngle(for move: Move) -> Double {
        let offset = move.probeOffset
        let local = arrowOrientation(for: move.face).inverse.act(
            SIMD3<Float>(Float(offset.x), Float(offset.y), Float(offset.z)))
        return Double(atan2(local.y, local.x)) * 180 / .pi
    }

    /// Rotation taking local +Z onto a face's outward normal. Everything about the arrow
    /// - where it sits, which way it sweeps - is expressed in the frame this defines.
    static func arrowOrientation(for face: Face) -> simd_quatf {
        switch face {
        case .F: return simd_quatf(angle: 0, axis: SIMD3(0, 1, 0))
        case .B: return simd_quatf(angle: .pi, axis: SIMD3(0, 1, 0))
        case .R: return simd_quatf(angle: .pi / 2, axis: SIMD3(0, 1, 0))
        case .L: return simd_quatf(angle: -.pi / 2, axis: SIMD3(0, 1, 0))
        case .U: return simd_quatf(angle: -.pi / 2, axis: SIMD3(1, 0, 0))
        case .D: return simd_quatf(angle: .pi / 2, axis: SIMD3(1, 0, 0))
        }
    }
}
