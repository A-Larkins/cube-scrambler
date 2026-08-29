import SwiftUI

struct ContentView: View {

    @StateObject private var store = Store()
    @StateObject private var session: ScrambleSession
    @State private var didStart = false

    init() {
        let store = Store()
        _store = StateObject(wrappedValue: store)
        _session = StateObject(wrappedValue: ScrambleSession(store: store))
    }

    var body: some View {
        HStack(spacing: 0) {
            main
            Divider()
            sidebar
                .frame(width: 268)
        }
        .frame(minWidth: 940, minHeight: 640)
        .background(Color(nsColor: .windowBackgroundColor))
        .focusable()
        .focusEffectDisabled()
        .onKeyPress(.rightArrow) { session.stepForward(); return .handled }
        .onKeyPress(.leftArrow) { session.stepBackward(); return .handled }
        .onKeyPress(.space) { session.toggleAutoPlay(); return .handled }
        .onKeyPress(.home) { session.jumpToStart(); return .handled }
        .onKeyPress(.end) { session.jumpToEnd(); return .handled }
        .onKeyPress(.init("r")) { Task { await session.newScramble() }; return .handled }
        .background { puzzleShortcuts }
        .task {
            guard !didStart else { return }
            didStart = true
            await session.start()
        }
    }

    /// Cmd-1 and Cmd-2 switch puzzles. A segmented picker cannot carry a keyboard
    /// shortcut, so these sit behind the layout as zero-sized buttons purely to hold them.
    private var puzzleShortcuts: some View {
        ZStack {
            Button("3x3") { Task { await session.switchTo(.three) } }
                .keyboardShortcut("1", modifiers: .command)
            Button("2x2") { Task { await session.switchTo(.two) } }
                .keyboardShortcut("2", modifiers: .command)
        }
        .frame(width: 0, height: 0)
        .opacity(0)
        .accessibilityHidden(true)
    }

    // MARK: - Left: the cube and the instruction

    private var main: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            ZStack {
                CubeSceneView(session: session, store: store)
                if session.isPreparing { preparing }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            MoveInstructionView(move: session.upcomingMove,
                                step: session.position + 1,
                                total: session.scramble.count,
                                isComplete: session.isComplete)
                .padding(.horizontal, 18)
            transport
                .padding(.vertical, 14)
        }
    }

    private var preparing: some View {
        VStack(spacing: 10) {
            ProgressView()
            Text("Working out the scramble tables\u{2026}")
                .font(.callout)
                .foregroundStyle(.secondary)
            Text("First launch only \u{2014} they're cached after this.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(24)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var toolbar: some View {
        HStack(spacing: 12) {
            Picker("", selection: Binding(
                get: { session.puzzle },
                set: { kind in Task { await session.switchTo(kind) } })) {
                    ForEach(PuzzleKind.allCases, id: \.self) { Text($0.displayName).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 132)

            Spacer()

            Toggle(isOn: $store.lockOrientation) {
                Label("Lock orientation", systemImage: store.lockOrientation ? "lock" : "lock.open")
            }
            .toggleStyle(.button)
            .help("Keep the camera still so the cube on screen matches the one in your hands. "
                  + "With it off, the view swings round to whichever face is turning.")

            Button {
                Task { await session.newScramble() }
            } label: {
                Label("New scramble", systemImage: "arrow.triangle.2.circlepath")
            }
            .disabled(session.isPreparing || session.isGenerating)
            .keyboardShortcut("n", modifiers: .command)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var transport: some View {
        HStack(spacing: 10) {
            Button { session.jumpToStart() } label: { Image(systemName: "backward.end.fill") }
                .disabled(session.position == 0)
                .help("Back to solved (Home)")

            Button { session.stepBackward() } label: { Image(systemName: "chevron.left") }
                .disabled(!session.canStepBackward)
                .help("Previous turn (\u{2190})")

            Button { session.stepForward() } label: {
                Label("Next turn", systemImage: "chevron.right")
            }
            .disabled(!session.canStepForward)
            .keyboardShortcut(.rightArrow, modifiers: [])
            .buttonStyle(.borderedProminent)
            .help("Make the next turn (\u{2192})")

            Button { session.toggleAutoPlay() } label: {
                Image(systemName: session.isAutoPlaying ? "pause.fill" : "play.fill")
            }
            .disabled(!session.canStepForward && !session.isAutoPlaying)
            .help("Play the rest of the scramble (Space)")

            Button { session.jumpToEnd() } label: { Image(systemName: "forward.end.fill") }
                .disabled(session.isComplete || session.scramble.isEmpty)
                .help("Skip to the scrambled state (End)")
        }
        .controlSize(.large)
    }

    // MARK: - Right: notation, net, history

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Scramble")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                ScrambleStripView(moves: session.scramble, position: session.position)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("All six faces")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                NetView(facelets: session.facelets)
                    .frame(height: 172)
                    .padding(.top, 4)
                Text("White on top, green in front.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Divider()

            HistorySidebarView(records: store.history,
                               onSelect: { session.load($0) },
                               onClear: { store.clearHistory() })
        }
        .padding(16)
        .frame(maxHeight: .infinity, alignment: .top)
    }
}
