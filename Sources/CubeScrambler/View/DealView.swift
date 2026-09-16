import SwiftUI

/// The deal number, and a way to go to one.
///
/// There is a finite number of scrambles, so each one can be numbered the way a game of
/// solitaire is. The number is not stored anywhere - it *is* the position, so typing one
/// back in always brings back the same scramble.
struct DealView: View {
    let deal: UInt128
    let puzzle: PuzzleKind
    let isBusy: Bool
    let onGo: (UInt128) -> Void
    let onStep: (Int) -> Void

    @State private var entry = ""
    @State private var rejected = false
    @FocusState private var editing: Bool

    private var total: UInt128 { Deal.total(for: puzzle) }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text("Deal")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                Spacer()
                Button { onStep(-1) } label: { Image(systemName: "chevron.left") }
                    .help("Previous deal")
                Button { onStep(1) } label: { Image(systemName: "chevron.right") }
                    .help("Next deal")
            }
            .buttonStyle(.borderless)
            .disabled(isBusy)

            // The number counts from 1, so the first deal is deal 1 rather than deal 0.
            Text(Deal.formatted(deal + 1))
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .textSelection(.enabled)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text("of \(Deal.formatted(total))")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.tertiary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            HStack(spacing: 6) {
                TextField("Go to deal\u{2026}", text: $entry)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 11, design: .monospaced))
                    .focused($editing)
                    .onSubmit(go)
                    .onChange(of: entry) { rejected = false }
                Button("Go", action: go)
                    .disabled(entry.isEmpty || isBusy)
            }
            .controlSize(.small)

            if rejected {
                Text("Pick a number from 1 to \(Deal.formatted(total)).")
                    .font(.caption2)
                    .foregroundStyle(.red)
            }
        }
    }

    private func go() {
        guard let number = Deal.parse(entry, puzzle: puzzle) else {
            rejected = !entry.isEmpty
            return
        }
        rejected = false
        entry = ""
        editing = false
        onGo(number)
    }
}
