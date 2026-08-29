import SwiftUI
import SceneKit

/// An SCNView that reports drags, so the cube can be turned round by hand.
final class OrbitSceneView: SCNView {
    var onDrag: ((CGFloat, CGFloat) -> Void)?

    override func mouseDragged(with event: NSEvent) {
        onDrag?(event.deltaX, event.deltaY)
    }

    override var acceptsFirstResponder: Bool { false }
}

/// Hosts the 3D cube and connects it to the session's stepping.
struct CubeSceneView: NSViewRepresentable {

    @ObservedObject var session: ScrambleSession
    @ObservedObject var store: Store

    @MainActor func makeCoordinator() -> Coordinator { Coordinator() }

    @MainActor final class Coordinator {
        let controller = CubeSceneController()
        var builtSize = 0
        var lastFacelets: Facelets?
    }

    func makeNSView(context: Context) -> OrbitSceneView {
        let view = OrbitSceneView()
        view.scene = context.coordinator.controller.scene
        view.backgroundColor = .clear
        view.antialiasingMode = .multisampling4X
        view.isPlaying = true
        view.onDrag = { dx, dy in
            Task { @MainActor in
                context.coordinator.controller.nudgeCamera(azimuthDelta: Double(dx) * 0.5,
                                                           elevationDelta: Double(-dy) * 0.5)
            }
        }
        sync(context.coordinator, force: true)
        wire(context.coordinator)
        return view
    }

    func updateNSView(_ view: OrbitSceneView, context: Context) {
        sync(context.coordinator, force: false)
        wire(context.coordinator)
    }

    /// Keeps the scene matching the session whenever something other than an animation
    /// changed it - a new scramble, a jump to the end, a switch between puzzles.
    @MainActor private func sync(_ coordinator: Coordinator, force: Bool) {
        let controller = coordinator.controller
        if coordinator.builtSize != session.puzzle.size {
            controller.build(size: session.puzzle.size)
            coordinator.builtSize = session.puzzle.size
            coordinator.lastFacelets = nil
        }
        guard !session.isAnimating else { return }
        let facelets = session.facelets
        if force || coordinator.lastFacelets != facelets {
            controller.update(facelets: facelets)
            coordinator.lastFacelets = facelets
        }
    }

    @MainActor private func wire(_ coordinator: Coordinator) {
        let controller = coordinator.controller
        session.animate = { [weak controller] move, forward in
            guard let controller else { return }
            let resulting = session.facelets(afterStep: forward)
            coordinator.lastFacelets = resulting
            controller.perform(move: move,
                               forward: forward,
                               resulting: resulting,
                               swingCamera: !store.lockOrientation) {
                session.animationFinished(forward: forward)
            }
        }
        session.resetCamera = { [weak controller] in controller?.resetCamera() }
    }
}
