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
    /// False until the user finishes or skips first-launch setup.
    public var hasCompletedOnboarding: Bool
    /// Plan actions the user has done, oldest first: what changed and when.
    public var changes: [SubscriptionChange]

    public init(
        services: [Service],
        watchlist: [WatchlistEntry],
        hasAmazonPrime: Bool,
        budget: Cents,
        hasCompletedOnboarding: Bool = true,
        changes: [SubscriptionChange] = []
    ) {
        self.services = services
        self.watchlist = watchlist
        self.hasAmazonPrime = hasAmazonPrime
        self.budget = budget
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.changes = changes
    }

    enum CodingKeys: String, CodingKey {
        case version, services, watchlist, hasAmazonPrime, budget, hasCompletedOnboarding, changes
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = try c.decodeIfPresent(Int.self, forKey: .version) ?? Self.currentVersion
        services = try c.decode([Service].self, forKey: .services)
        watchlist = try c.decode([WatchlistEntry].self, forKey: .watchlist)
        hasAmazonPrime = try c.decode(Bool.self, forKey: .hasAmazonPrime)
        budget = try c.decode(Cents.self, forKey: .budget)
        // Saved before onboarding existed: that user is already set up.
        hasCompletedOnboarding = try c.decodeIfPresent(Bool.self, forKey: .hasCompletedOnboarding) ?? true
        // Files from before this existed may have a "doneActions" list; it only
        // hid reminders, so it's ignored.
        changes = try c.decodeIfPresent([SubscriptionChange].self, forKey: .changes) ?? []
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
