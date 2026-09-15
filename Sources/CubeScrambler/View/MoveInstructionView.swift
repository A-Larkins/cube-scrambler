import SwiftUI

/// The move you are being asked to make, spelled out.
///
/// The notation alone is the problem this app exists to fix, so it never appears on its
/// own: the glyph is always paired with a plain instruction - which part of the cube, which
/// colour its centre is, and which way it goes - as you see it holding the cube.
struct MoveInstructionView: View {
    let move: Move?
    let step: Int          // 1-based position of this move in the scramble
    let total: Int
    let isComplete: Bool
    let hold: Hold

    var body: some View {
        HStack(alignment: .center, spacing: 20) {
            glyph
            if let move {
                let instruction = move.instruction
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text(instruction.sentence)
                            .font(.system(size: 22, weight: .semibold, design: .rounded))
                        Text(instruction.symbol)
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundStyle(Palette.accent)
                    }
                    Text(instruction.detail)
                        .font(.system(size: 14, design: .rounded))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 14) {
                        centreChip(for: move.face)
                        if step == 1 {
                            Text("Start solved. " + hold.instruction)
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(Palette.accent)
                        }
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Text(isComplete ? "Scrambled \u{2014} ready to solve."
                                    : "Start with a solved cube.")
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                    Text(isComplete ? "Check your cube against the six faces on the right."
                                    : hold.instruction + " Then press \u{2192} for the first turn.")
                        .font(.system(size: 14, design: .rounded))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
            counter
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 16)
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

    /// Names the centre colour, since that is what you actually look for on the cube.
    private func centreChip(for face: Face) -> some View {
        let color = hold.color(of: face)
        return HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(Palette.color(color))
                .overlay(RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .strokeBorder(Color.black.opacity(0.35), lineWidth: 1))
                .frame(width: 14, height: 14)
            Text("the \(color.name) centre")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
        }
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
                Text(move == nil ? (isComplete ? "done" : "ready") : "Move \(step)")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                Text("of \(total)")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
    }
}
