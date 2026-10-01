import Foundation

/// Reads and writes `SavedState` as a JSON file.
public struct Store: Sendable {
    public let url: URL

    public init(url: URL = Store.defaultURL) {
        self.url = url
    }

    /// Application Support/state.json: private to the app, backed up, not
    /// visible in the Files app.
    public static var defaultURL: URL {
        URL.applicationSupportDirectory.appending(path: "state.json")
    }

    public enum LoadResult: Equatable, Sendable {
        /// First launch: nothing saved yet.
        case empty
        case loaded(SavedState)
        /// The file couldn't be read. It was moved to `movedTo` (if possible)
        /// so the next save doesn't overwrite it.
        case damaged(movedTo: URL?)
    }

    public func load() -> LoadResult {
        // Not `url.path()`: that's percent-encoded ("Application%20Support"),
        // so the file would look missing and get overwritten with sample data.
        guard FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) else { return .empty }
        do {
            let state = try JSONDecoder().decode(SavedState.self, from: Data(contentsOf: url))
            return .loaded(state.sanitized())
        } catch {
            let aside = url.deletingPathExtension().appendingPathExtension("damaged.json")
            try? FileManager.default.removeItem(at: aside)
            let moved = (try? FileManager.default.moveItem(at: url, to: aside)) != nil
            return .damaged(movedTo: moved ? aside : nil)
        }
    }

    public func save(_ state: SavedState) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(state)
        #if os(iOS)
        // Encrypted while the phone is locked before first unlock after a restart.
        try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        #else
        try data.write(to: url, options: .atomic)
        #endif
    }
}
