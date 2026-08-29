import Foundation

/// Where the generated lookup tables live between launches.
///
/// Everything here is derived data: deleting the directory costs one slow launch and
/// nothing else. The filenames carry a version so a change to a table's layout can never
/// read stale bytes from an older build.
enum TableCache {

    static var directory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory,
                                            in: .userDomainMask)[0]
        return base.appendingPathComponent("CubeScrambler", isDirectory: true)
    }

    static func url(_ name: String) -> URL {
        directory.appendingPathComponent(name)
    }

    static func load(_ name: String, expectedCount: Int) -> [UInt8]? {
        guard let data = try? Data(contentsOf: url(name)), data.count == expectedCount else {
            return nil
        }
        return [UInt8](data)
    }

    static func save(_ bytes: [UInt8], as name: String) {
        do {
            try FileManager.default.createDirectory(at: directory,
                                                    withIntermediateDirectories: true)
            try Data(bytes).write(to: url(name), options: .atomic)
        } catch {
            // A cache that fails to write just means the next launch rebuilds it.
            NSLog("CubeScrambler: could not cache \(name): \(error.localizedDescription)")
        }
    }

    /// Loads a cached table, or builds and caches it.
    static func loadOrBuild(_ name: String, count: Int, build: () -> [UInt8]) -> [UInt8] {
        if let cached = load(name, expectedCount: count) { return cached }
        let built = build()
        save(built, as: name)
        return built
    }
}
