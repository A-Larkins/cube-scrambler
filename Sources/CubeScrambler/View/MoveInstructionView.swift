import SwiftUI

/// The move you are being asked to make, spelled out.
///
/// The notation alone is the problem this app exists to fix, so it never appears on its
/// own: the glyph is always paired with a sentence naming the face and the direction the
/// stickers travel, in the same fixed frame the 3D cube is showing.
struct MoveInstructionView: View {
    let move: Move?
    let step: Int          // 1-based position of this move in the scramble
    let total: Int
    let isComplete: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 20) {
            glyph
            if let move {
                VStack(alignment: .leading, spacing: 5) {
                    Text(move.instruction.sentence)
                        .font(.system(size: 19, weight: .medium, design: .rounded))
                        .fixedSize(horizontal: false, vertical: true)
                    if let note = move.instruction.visibilityNote {
                        Text(note)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 5) {
                    Text(isComplete ? "Scrambled \u{2014} ready to solve."
                                    : "Press \u{2192} to start scrambling.")
                        .font(.system(size: 19, weight: .medium, design: .rounded))
                    Text(isComplete ? "Compare your cube with the net on the right."
                                    : "The cube starts solved and stays put until you step.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
            counter
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(move == nil ? Color.secondary.opacity(0.25) : Palette.accent.opacity(0.55),
                              lineWidth: 1.5)
        )
    }

    private var glyph: some View {
        Text(move?.prettyNotation ?? "\u{2713}")
            .font(.system(size: 46, weight: .bold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(move == nil ? Color.secondary : Palette.accent)
            .frame(minWidth: 74, alignment: .leading)
    }

    @ViewBuilder private var counter: some View {
        if total > 0 {
            VStack(alignment: .trailing, spacing: 2) {
                Text(move == nil ? "done" : "Move \(step)")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                Text("of \(total)")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
    }
}
