import Foundation
import RotationEngine

/// Everything the app saves, in one file.
public struct SavedState: Codable, Equatable, Sendable {
    public static let currentVersion = 1

    public var version = SavedState.currentVersion
    public var services: [Service]
    /// Order is priority.
    public var watchlist: [WatchlistEntry]
    public var hasAmazonPrime: Bool
    public var budget: Cents

    public init(services: [Service], watchlist: [WatchlistEntry], hasAmazonPrime: Bool, budget: Cents) {
        self.services = services
        self.watchlist = watchlist
        self.hasAmazonPrime = hasAmazonPrime
        self.budget = budget
    }

    /// Fix values that would break planning or the screens: negative prices,
    /// impossible renewal days, zero-month titles, duplicate ids, no budget.
    public func sanitized() -> SavedState {
        var state = self
        state.services = services.map { service in
            var s = service
            s.price = max(0, s.price)
            s.renews = s.renews.map { min(max($0, 1), 31) }
            return s
        }
        var seen = Set<String>()
        state.watchlist = watchlist.map { entry in
            var e = entry
            e.months = e.months.map { max(1, $0) }
            if !seen.insert(e.id).inserted {
                e.id = UUID().uuidString
                seen.insert(e.id)
            }
            return e
        }
        state.budget = max(1_00, budget)
        return state
    }
}
