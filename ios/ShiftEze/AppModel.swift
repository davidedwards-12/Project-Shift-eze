import Foundation
import Observation
import Persistence
import RotationEngine

/// The user's subscriptions, watchlist and budget. Every change is saved to
/// the phone, and the plan is recomputed from them whenever it's read.
@Observable
final class AppModel {
    var services: [Service] { didSet { save() } }
    /// Order is priority: earlier titles are planned sooner.
    var watchlist: [WatchlistEntry] { didSet { save() } }
    var hasAmazonPrime: Bool { didSet { save() } }
    var budget: Cents { didSet { save() } }

    /// Shown once when saved data couldn't be read or written.
    var storageNotice: String?

    /// Nil for previews: nothing is saved.
    @ObservationIgnored private let store: Store?

    init(state: SavedState, store: Store?) {
        services = state.services
        watchlist = state.watchlist
        hasAmazonPrime = state.hasAmazonPrime
        budget = state.budget
        self.store = store
    }

    /// Load saved data; sample data on first launch or if the file is damaged.
    static func launch(store: Store = Store()) -> AppModel {
        switch store.load() {
        case .loaded(let state):
            return AppModel(state: state, store: store)
        case .empty:
            let model = AppModel(state: .sample, store: store)
            model.save()
            return model
        case .damaged:
            let model = AppModel(state: .sample, store: store)
            model.storageNotice = "Your saved data couldn't be read, so the app started over with sample data. A copy of the old file was kept."
            model.save()
            return model
        }
    }

    /// For previews: sample data, never saved.
    static func sample() -> AppModel { AppModel(state: .sample, store: nil) }

    func resetToSample() {
        let sample = SavedState.sample
        services = sample.services
        watchlist = sample.watchlist
        hasAmazonPrime = sample.hasAmazonPrime
        budget = sample.budget
    }

    private var state: SavedState {
        SavedState(services: services, watchlist: watchlist, hasAmazonPrime: hasAmazonPrime, budget: budget)
    }

    private func save() {
        guard let store else { return }
        do {
            try store.save(state)
        } catch {
            storageNotice = "Couldn't save your changes. They'll be lost when the app closes."
        }
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

extension SavedState {
    /// The sample subscriptions and watchlist bundled with the app.
    static var sample: SavedState {
        let config = SampleData.load("services", as: ServicesFile.self)
        let watchlist = SampleData.load("watchlist", as: WatchlistFile.self)
        return SavedState(
            services: config.services,
            watchlist: watchlist.titles,
            hasAmazonPrime: config.memberships?["amazon_prime"] ?? false,
            budget: 40_00
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
