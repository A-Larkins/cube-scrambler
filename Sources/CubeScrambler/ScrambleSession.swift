import Foundation
import SwiftUI

/// Generates scrambles off the main thread and keeps the next one ready.
///
/// A 3x3 random-state search takes a few hundred milliseconds, which would be a visible
/// stutter on every press of "New scramble". So one is always being generated in the
/// background while you work through the current one, and pressing the button just hands
/// over the finished result.
actor ScrambleGenerator {

    private var prefetched: [PuzzleKind: Deal.Dealt] = [:]

    /// Forces the lookup tables to be built (or loaded from cache) before first use.
    func prepare() {
        _ = Tables333.shared.sliceTwistPrune.first
        _ = Scrambler222.distances.first
    }

    func next(for puzzle: PuzzleKind) -> Deal.Dealt {
        if let ready = prefetched.removeValue(forKey: puzzle) { return ready }
        return generate(for: puzzle)
    }

    /// The scramble for one particular deal number, worked out on demand.
    func dealt(_ number: UInt128, for puzzle: PuzzleKind) -> Deal.Dealt {
        Deal.Dealt(number: number, moves: Dealer.moves(forDeal: number, puzzle: puzzle))
    }

    func prefetch(for puzzle: PuzzleKind) {
        guard prefetched[puzzle] == nil else { return }
        prefetched[puzzle] = generate(for: puzzle)
    }

    private func generate(for puzzle: PuzzleKind) -> Deal.Dealt {
        var rng = SystemRandomNumberGenerator()
        let number = Dealer.randomDeal(puzzle: puzzle, using: &rng)
        return Deal.Dealt(number: number, moves: Dealer.moves(forDeal: number, puzzle: puzzle))
    }
}

/// The state the whole interface reads from: which scramble, and how far through it we are.
@MainActor
final class ScrambleSession: ObservableObject {

    /// The scramble, as a list of turns from a solved cube.
    @Published private(set) var scramble: [Move] = []
    /// Which of the puzzle's finite scrambles this one is, counting from 0.
    @Published private(set) var deal: UInt128 = 0
    /// How many of those turns have been applied. 0 is solved, `scramble.count` is done.
    @Published private(set) var position: Int = 0
    @Published private(set) var isPreparing = true
    @Published private(set) var isGenerating = false
    @Published var isAutoPlaying = false
    /// Set while a turn is animating, so input can't run two turns at once.
    @Published private(set) var isAnimating = false

    @Published var puzzle: PuzzleKind = .three

    private let generator = ScrambleGenerator()
    private let store: Store
    /// Called when a turn should be animated. The scene sets these up.
    var animate: ((Move, Bool) -> Void)?
    var resetCamera: (() -> Void)?

    init(store: Store) {
        self.store = store
        self.puzzle = store.puzzle
    }

    // MARK: - Derived state

    /// The cube as it stands right now, with `position` turns applied.
    var cube: CubieCube {
        CubieCube.solved.applying(Array(scramble.prefix(position)))
    }

    var facelets: Facelets {
        Facelets.from(cube: cube, puzzle: puzzle)
    }

    /// How the cube will look once the step now being animated finishes. The scene needs
    /// this up front, because `position` only advances when the animation lands.
    func facelets(afterStep forward: Bool) -> Facelets {
        let count = forward ? position + 1 : position - 1
        let cube = CubieCube.solved.applying(Array(scramble.prefix(max(0, count))))
        return Facelets.from(cube: cube, puzzle: puzzle)
    }

    /// The turn you are being asked to make next, or nil once the scramble is finished.
    var upcomingMove: Move? {
        position < scramble.count ? scramble[position] : nil
    }

    var isComplete: Bool { !scramble.isEmpty && position == scramble.count }
    var canStepForward: Bool { position < scramble.count && !isAnimating }
    var canStepBackward: Bool { position > 0 && !isAnimating }

    // MARK: - Lifecycle

    func start() async {
        await generator.prepare()
        isPreparing = false
        await newScramble(recordPrevious: false)
    }

    func newScramble(recordPrevious: Bool = true) async {
        guard !isPreparing else { return }
        isAutoPlaying = false
        isGenerating = true
        let kind = puzzle
        let dealt = await generator.next(for: kind)
        apply(dealt, puzzle: kind)
        Task.detached(priority: .background) { [generator] in
            await generator.prefetch(for: kind)
        }
    }

    func load(_ record: ScrambleRecord) {
        isAutoPlaying = false
        puzzle = record.puzzle
        store.puzzle = record.puzzle
        scramble = record.moves
        deal = record.deal
        position = 0
    }

    /// Goes to a deal by number - the same number always brings back the same scramble.
    func goToDeal(_ number: UInt128) async {
        guard !isPreparing, number != deal || scramble.isEmpty else { return }
        isAutoPlaying = false
        isGenerating = true
        let kind = puzzle
        let dealt = await generator.dealt(number, for: kind)
        apply(dealt, puzzle: kind)
    }

    /// The deal before or after this one, wrapping at either end of the puzzle.
    func stepDeal(by offset: Int) async {
        let total = Deal.total(for: puzzle)
        let next = offset < 0 ? (deal == 0 ? total - 1 : deal - 1)
                              : (deal + 1 == total ? 0 : deal + 1)
        await goToDeal(next)
    }

    private func apply(_ dealt: Deal.Dealt, puzzle kind: PuzzleKind) {
        scramble = dealt.moves
        deal = dealt.number
        position = 0
        isGenerating = false
        store.record(dealt, puzzle: kind)
    }

    func switchTo(_ kind: PuzzleKind) async {
        guard kind != puzzle else { return }
        puzzle = kind
        store.puzzle = kind
        await newScramble()
    }

    // MARK: - Stepping

    func stepForward() {
        guard canStepForward, let move = upcomingMove else { return }
        isAnimating = true
        animate?(move, true)
    }

    func stepBackward() {
        guard canStepBackward else { return }
        isAnimating = true
        animate?(scramble[position - 1], false)
    }

    /// A beat between turns while auto-playing, so the finished position is readable
    /// before the next arrow appears.
    static let autoPlayPause: TimeInterval = 0.3

    /// Called by the scene when a turn has finished animating.
    func animationFinished(forward: Bool) {
        position += forward ? 1 : -1
        isAnimating = false
        guard isAutoPlaying else { return }
        guard canStepForward else { isAutoPlaying = false; return }
        Task {
            try? await Task.sleep(for: .seconds(ScrambleSession.autoPlayPause))
            guard isAutoPlaying, canStepForward else { return }
            stepForward()
        }
    }

    /// Puts the cube just before turn `index`, so that turn is the one on show - its arrow
    /// on the cube and its instruction below. Choosing the turn already on show makes it.
    func select(_ index: Int) {
        guard scramble.indices.contains(index), !isAnimating else { return }
        isAutoPlaying = false
        if index == position {
            stepForward()
        } else {
            position = index
        }
    }

    func jumpToStart() {
        isAutoPlaying = false
        position = 0
    }

    func jumpToEnd() {
        isAutoPlaying = false
        position = scramble.count
    }

    func toggleAutoPlay() {
        if isAutoPlaying {
            isAutoPlaying = false
        } else if canStepForward {
            isAutoPlaying = true
            stepForward()
        }
    }
}
