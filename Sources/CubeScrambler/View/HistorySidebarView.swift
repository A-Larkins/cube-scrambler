import SwiftUI

/// Recent scrambles, so a good one can be stepped through again.
struct HistorySidebarView: View {
    let records: [ScrambleRecord]
    let onSelect: (ScrambleRecord) -> Void
    let onClear: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("History")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                Spacer()
                if !records.isEmpty {
                    Button("Clear", action: onClear)
                        .buttonStyle(.link)
                        .font(.caption)
                }
            }

            if records.isEmpty {
                Text("Scrambles you generate will collect here.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.top, 2)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(records) { record in
                            Button { onSelect(record) } label: { row(record) }
                                .buttonStyle(.plain)
                        }
                    }
                }
            }
            Spacer(minLength: 0)
        }
    }

    private func row(_ record: ScrambleRecord) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Text(record.puzzle.displayName)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(Capsule().fill(Color.secondary.opacity(0.18)))
                Text(record.date, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Text(record.moves.prettyNotation)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 5)
        .padding(.horizontal, 7)
        .contentShape(Rectangle())
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(Color.secondary.opacity(0.07))
        )
    }
}
