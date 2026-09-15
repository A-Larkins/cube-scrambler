import Foundation

/// One scramble worth keeping.
struct ScrambleRecord: Identifiable, Equatable {
    let id: UUID
    let puzzle: PuzzleKind
    let moves: [Move]
    let date: Date

    init(id: UUID = UUID(), puzzle: PuzzleKind, moves: [Move], date: Date = Date()) {
        self.id = id; self.puzzle = puzzle; self.moves = moves; self.date = date
    }
}

/// Settings and scramble history, in Application Support alongside the lookup tables.
///
/// Everything decodes field by field with a fallback rather than as one `Codable` struct.
/// A whole-struct decode fails outright when a new field appears, which silently throws
/// away the saved file the first time the format changes.
@MainActor
final class Store: ObservableObject {

    @Published var history: [ScrambleRecord] = []
    @Published var puzzle: PuzzleKind = .three { didSet { saveSettings() } }
    @Published var lockOrientation: Bool = false { didSet { saveSettings() } }
    @Published var hold: Hold = .standard { didSet { saveSettings() } }

    static let historyLimit = 50

    private var historyURL: URL { TableCache.url("history.json") }
    private var settingsURL: URL { TableCache.url("settings.json") }

    init() {
        loadSettings()
        loadHistory()
    }

    // MARK: - History

    func record(_ moves: [Move], puzzle: PuzzleKind) {
        guard !moves.isEmpty else { return }
        history.insert(ScrambleRecord(puzzle: puzzle, moves: moves), at: 0)
        if history.count > Store.historyLimit { history.removeLast(history.count - Store.historyLimit) }
        saveHistory()
    }

    func clearHistory() {
        history.removeAll()
        saveHistory()
    }

    private func loadHistory() {
        guard let data = try? Data(contentsOf: historyURL),
              let raw = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        else { return }

        history = raw.compactMap { entry in
            guard let notation = entry["moves"] as? String else { return nil }
            let moves = Move.parse(notation)
            guard !moves.isEmpty else { return nil }
            let puzzle = (entry["puzzle"] as? String).flatMap(PuzzleKind.init(rawValue:)) ?? .three
            let date = (entry["date"] as? TimeInterval).map(Date.init(timeIntervalSince1970:)) ?? Date()
            let id = (entry["id"] as? String).flatMap(UUID.init(uuidString:)) ?? UUID()
            return ScrambleRecord(id: id, puzzle: puzzle, moves: moves, date: date)
        }
    }

    private func saveHistory() {
        let raw: [[String: Any]] = history.map {
            ["id": $0.id.uuidString,
             "puzzle": $0.puzzle.rawValue,
             "moves": $0.moves.notation,
             "date": $0.date.timeIntervalSince1970]
        }
        write(raw, to: historyURL)
    }

    // MARK: - Settings

    private func loadSettings() {
        guard let data = try? Data(contentsOf: settingsURL),
              let raw = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return }
        if let value = (raw["puzzle"] as? String).flatMap(PuzzleKind.init(rawValue:)) { puzzle = value }
        if let value = raw["lockOrientation"] as? Bool { lockOrientation = value }
        if let value = (raw["hold"] as? String).flatMap(Hold.init(rawValue:)) { hold = value }
    }

    private func saveSettings() {
        write(["puzzle": puzzle.rawValue, "lockOrientation": lockOrientation, "hold": hold.rawValue],
              to: settingsURL)
    }

    private func write(_ object: Any, to url: URL) {
        do {
            try FileManager.default.createDirectory(at: TableCache.directory,
                                                    withIntermediateDirectories: true)
            let data = try JSONSerialization.data(withJSONObject: object,
                                                  options: [.prettyPrinted, .sortedKeys])
            try data.write(to: url, options: .atomic)
        } catch {
            NSLog("CubeScrambler: could not save \(url.lastPathComponent): \(error)")
        }
    }
}
