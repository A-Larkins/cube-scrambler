import SwiftUI

/// The cube unfolded flat, so all six faces are visible at once.
///
/// The 3D view is what tells you which way a face is turning; this is what tells you
/// whether you got it right, including the three faces you cannot see from the front.
struct NetView: View {
    let facelets: Facelets
    let hold: Hold
    var showsLabels = true

    /// Column and row of each face in the standard cross layout:
    ///
    ///       U
    ///     L F R B
    ///       D
    private static let layout: [(face: Face, col: Int, row: Int)] = [
        (.U, 1, 0),
        (.L, 0, 1), (.F, 1, 1), (.R, 2, 1), (.B, 3, 1),
        (.D, 1, 2)
    ]

    var body: some View {
        GeometryReader { geometry in
            let n = facelets.size
            let columnGap: CGFloat = 5
            // Rows need more room than columns: the face letter sits in the gap above
            // each face, and a tight gap put it on top of the row before.
            let rowGap: CGFloat = showsLabels ? 15 : 5
            let cell = min((geometry.size.width - 3 * columnGap) / CGFloat(4 * n),
                           (geometry.size.height - 2 * rowGap) / CGFloat(3 * n))
            let faceSide = cell * CGFloat(n)
            let width = faceSide * 4 + columnGap * 3
            let height = faceSide * 3 + rowGap * 2
            let originX = (geometry.size.width - width) / 2
            let originY = (geometry.size.height - height) / 2

            ZStack(alignment: .topLeading) {
                ForEach(Self.layout, id: \.face) { entry in
                    face(entry.face, cell: cell, count: n)
                        .frame(width: faceSide, height: faceSide)
                        .offset(x: originX + CGFloat(entry.col) * (faceSide + columnGap),
                                y: originY + CGFloat(entry.row) * (faceSide + rowGap))
                }
            }
        }
    }

    private func face(_ face: Face, cell: CGFloat, count n: Int) -> some View {
        VStack(spacing: 1) {
            ForEach(0..<n, id: \.self) { row in
                HStack(spacing: 1) {
                    ForEach(0..<n, id: \.self) { col in
                        RoundedRectangle(cornerRadius: cell * 0.2, style: .continuous)
                            .fill(Palette.sticker(facelets.color(face: face, row: row, col: col), hold: hold))
                    }
                }
            }
        }
        .padding(1)
        .background(
            RoundedRectangle(cornerRadius: cell * 0.3, style: .continuous)
                .fill(Color.black.opacity(0.55))
        )
        .overlay(alignment: .topLeading) {
            if showsLabels {
                Text(face.letter)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .offset(x: 1, y: -13)
            }
        }
    }
}
