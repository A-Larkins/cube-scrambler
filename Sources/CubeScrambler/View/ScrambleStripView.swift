import SwiftUI

/// Wraps items onto as many rows as it takes. The scramble strip needs it because a
/// 20-move scramble rarely fits on one line at a readable size.
struct FlowLayout: Layout {
    var spacing: CGFloat = 6
    var lineSpacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        let rows = arrange(subviews: subviews, in: width)
        let height = rows.reduce(0) { $0 + $1.height } + lineSpacing * CGFloat(max(0, rows.count - 1))
        return CGSize(width: proposal.width ?? rows.map(\.width).max() ?? 0, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize,
                       subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arrange(subviews: subviews, in: bounds.width) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y + (row.height - size.height) / 2),
                                      proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + lineSpacing
        }
    }

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func arrange(subviews: Subviews, in width: CGFloat) -> [Row] {
        var rows: [Row] = []
        var current = Row()
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let needed = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            if needed > width, !current.indices.isEmpty {
                rows.append(current)
                current = Row()
                current.indices = [index]
                current.width = size.width
                current.height = size.height
            } else {
                current.indices.append(index)
                current.width = needed
                current.height = max(current.height, size.height)
            }
        }
        if !current.indices.isEmpty { rows.append(current) }
        return rows
    }
}

/// The whole scramble in notation, with the move you are on picked out.
struct ScrambleStripView: View {
    let moves: [Move]
    /// Number of moves already applied; the move at this index is the one coming up.
    let position: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            FlowLayout(spacing: 5, lineSpacing: 5) {
                ForEach(Array(moves.enumerated()), id: \.offset) { index, move in
                    token(move, state: state(for: index))
                }
            }
            progress
        }
    }

    private enum TokenState { case done, current, pending }

    private func state(for index: Int) -> TokenState {
        if index < position { return .done }
        if index == position { return .current }
        return .pending
    }

    private func token(_ move: Move, state: TokenState) -> some View {
        Text(move.prettyNotation)
            .font(.system(size: 15, weight: state == .current ? .bold : .medium, design: .monospaced))
            .foregroundStyle(state == .done ? Color.secondary.opacity(0.55)
                             : state == .current ? Color.primary : Color.primary.opacity(0.85))
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(state == .current ? Palette.accent.opacity(0.28) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(state == .current ? Palette.accent : Color.clear, lineWidth: 1.5)
            )
    }

    private var progress: some View {
        VStack(alignment: .leading, spacing: 5) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.secondary.opacity(0.2))
                    Capsule()
                        .fill(Palette.accent)
                        .frame(width: moves.isEmpty ? 0
                               : geometry.size.width * CGFloat(position) / CGFloat(moves.count))
                }
            }
            .frame(height: 5)
            Text(moves.isEmpty ? " " : "\(position) of \(moves.count) turns made")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
