import Foundation
import Observation
import RotationEngine

/// The user's subscriptions, watchlist and budget. The plan is recomputed from
/// them whenever it's read, so every edit is reflected immediately.
///
/// In-memory only for now: edits reset on relaunch until on-device storage lands.
@Observable
final class AppModel {
    var services: [Service]
    /// Order is priority: earlier titles are planned sooner.
    var watchlist: [WatchlistEntry]
    var hasAmazonPrime: Bool
    var budget: Cents = 40_00

    init(services: [Service], watchlist: [WatchlistEntry], hasAmazonPrime: Bool) {
        self.services = services
        self.watchlist = watchlist
        self.hasAmazonPrime = hasAmazonPrime
    }

    var today: CalendarDate { .today }
    /// Plans start with next calendar month.
    var start: CalendarDate { today.firstOfNextMonth }

    var plan: Result<RotationPlan, RotationPlan.Failure> {
        do {
            return .success(try RotationPlan.make(
                services: services,
                watchlist: watchlist,
                memberships: ["amazon_prime": hasAmazonPrime],
                budget: budget,
                start: start,
                today: today
            ))
        } catch {
            return .failure(error)
        }
    }

    /// Watchlist titles with provider names normalized, for display.
    var titles: [Title] {
        Planning.prepare(services: services, watchlist: watchlist).1
    }
}

extension AppModel {
    /// The sample subscriptions and watchlist bundled with the app.
    static func sample() -> AppModel {
        let config = SampleData.load("services", as: ServicesFile.self)
        let watchlist = SampleData.load("watchlist", as: WatchlistFile.self)
        return AppModel(
            services: config.services,
            watchlist: watchlist.titles,
            hasAmazonPrime: config.memberships?["amazon_prime"] ?? false
        )
    }
}

private struct ServicesFile: Decodable {
    var memberships: [String: Bool]?
    var services: [Service]
}

private struct WatchlistFile: Decodable {
    var titles: [WatchlistEntry]
}

private enum SampleData {
    static func load<T: Decodable>(_ name: String, as type: T.Type) -> T {
        guard let url = Bundle.main.url(forResource: name, withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let value = try? JSONDecoder().decode(T.self, from: data)
        else { fatalError("Bundled sample data \(name).json is missing or invalid") }
        return value
    }
}
