import Foundation
import Observation
import Persistence
import RotationEngine
import TMDB

/// The user's subscriptions, watchlist and budget. Every change is saved to
/// the phone, and the plan is recomputed from them whenever it's read.
@Observable
final class AppModel {
    var services: [Service] { didSet { save() } }
    /// Order is priority: earlier titles are planned sooner.
    var watchlist: [WatchlistEntry] { didSet { save() } }
    var hasAmazonPrime: Bool { didSet { save() } }
    var budget: Cents { didSet { save() } }
    /// False until first-launch setup is finished or skipped.
    var hasCompletedOnboarding: Bool { didSet { save() } }
    /// Plan actions the user has done, oldest first.
    var changes: [SubscriptionChange] { didSet { save() } }

    /// Shown once when saved data couldn't be read or written.
    var storageNotice: String?
    /// Watchlist ids whose availability is being re-checked right now.
    var refreshing: Set<String> = []

    /// Nil for previews: nothing is saved.
    @ObservationIgnored private let store: Store?

    init(state: SavedState, store: Store?) {
        services = state.services
        watchlist = state.watchlist
        hasAmazonPrime = state.hasAmazonPrime
        budget = state.budget
        hasCompletedOnboarding = state.hasCompletedOnboarding
        changes = state.changes
        self.store = store
    }

    /// Load saved data. First launch, or a damaged file, starts empty and
    /// goes through onboarding.
    static func launch(store: Store = Store()) -> AppModel {
        switch store.load() {
        case .loaded(let state):
            return AppModel(state: state, store: store)
        case .empty:
            let model = AppModel(state: .newUser, store: store)
            model.save()
            return model
        case .damaged:
            let model = AppModel(state: .newUser, store: store)
            model.storageNotice = "Your saved data couldn't be read, so the app started over. A copy of the old file was kept."
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
        hasCompletedOnboarding = true
        changes = []
    }

    /// For testing: show first-launch setup again, keeping current data.
    func restartOnboarding() {
        hasCompletedOnboarding = false
    }

    private var state: SavedState {
        SavedState(services: services, watchlist: watchlist, hasAmazonPrime: hasAmazonPrime,
                   budget: budget, hasCompletedOnboarding: hasCompletedOnboarding, changes: changes)
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

    // MARK: - Reminders
    
    /// Notifications for the plan's upcoming actions
    var reminders: [Reminder] {
        guard case .success(let plan) = plan else { return [] }
        return Reminders.make(plan: plan, today: today)
    }

    // MARK: - Done actions

    /// The user did `action`: update their subscriptions to match (cancelled
    /// or started) and keep a record so it can be undone. The plan, Services
    /// tab and savings all follow.
    func markDone(_ action: Action) {
        var updated = services
        guard let change = SubscriptionChanges.apply(action, on: today, to: &updated) else { return }
        services = updated
        changes.append(change)
    }

    func undo(_ change: SubscriptionChange) {
        var updated = services
        SubscriptionChanges.undo(change, in: &updated)
        services = updated
        changes.removeAll { $0.id == change.id }
    }

    /// Changes from the last 30 days, newest first, for "Done recently".
    var recentChanges: [SubscriptionChange] {
        changes.filter { $0.doneOn.days(to: today) <= 30 }.reversed()
    }

    /// When a cancelled service stops: shown while it's still paid up.
    func paidUntil(_ service: String) -> CalendarDate? {
        changes.last { $0.service == service && $0.kind == .cancelled && $0.effectiveOn >= today }?.effectiveOn
    }
    
    // MARK: - Availability

    /// Re-check where watchlist titles stream: anything older than a week,
    /// or a day for titles behind a Start/Restart in the next week. Failures
    /// (offline, TMDB down) keep the old data and are retried next time.
    func refreshAvailability() async {
        guard let client = AppConfig.tmdbClient else { return }
        let due = Set(AvailabilityRefresh.due(watchlist, today: today, urgent: idsBehindUpcomingStarts))
            .subtracting(refreshing)
        guard !due.isEmpty else { return }
        refreshing.formUnion(due)
        // One at a time, in watchlist order, to stay well inside TMDB's limits.
        for entry in watchlist where due.contains(entry.id) {
            if let updated = try? await client.refreshed(entry, today: today),
               let index = watchlist.firstIndex(where: { $0.id == entry.id }) {
                watchlist[index] = updated
            }
            refreshing.remove(entry.id)
        }
        refreshing.subtract(due)
    }

    enum CheckResult: Equatable {
        case unchanged, changed
        case failed(String)
    }

    /// "Check again now": re-check one title and say what happened, so the
    /// user gets an answer even when nothing changed.
    func checkNow(_ id: String) async -> CheckResult {
        guard let client = AppConfig.tmdbClient else { return .failed("TMDB key not set.") }
        guard let entry = watchlist.first(where: { $0.id == id }) else { return .failed("It's no longer on your watchlist.") }
        let started = ContinuousClock.now
        refreshing.insert(id)
        defer { refreshing.remove(id) }

        let result: CheckResult
        do {
            if let updated = try await client.refreshed(entry, today: today),
               let index = watchlist.firstIndex(where: { $0.id == id }) {
                let changed = watchlist[index].services != updated.services || watchlist[index].free != updated.free
                watchlist[index] = updated
                result = changed ? .changed : .unchanged
            } else {
                result = .failed("This title can't be re-checked.")
            }
        } catch {
            result = .failed(error.userMessage)
        }
        // A check often takes a fraction of a second; keep "Checking…" up
        // long enough to see that something happened.
        try? await Task.sleep(until: started + .milliseconds(700))
        return result
    }

    /// Say a title isn't (or is after all) on a service, whatever TMDB says.
    func setNotOn(_ service: String, _ isNotOn: Bool, titleID: String) {
        guard let index = watchlist.firstIndex(where: { $0.id == titleID }) else { return }
        var notOn = Set(watchlist[index].notOn ?? [])
        if isNotOn { notOn.insert(service) } else { notOn.remove(service) }
        watchlist[index].notOn = notOn.isEmpty ? nil : notOn.sorted()
    }

    /// Titles the plan will soon have the user subscribe for: worth checking
    /// daily so we don't send them to a service that's dropped the title.
    private var idsBehindUpcomingStarts: Set<String> {
        guard case .success(let plan) = plan else { return [] }
        let services = Set(plan.actions
            .filter { ($0.kind == .start || $0.kind == .restart) && today.days(to: $0.date) <= 7 }
            .map(\.service))
        return Set(plan.cover.assignment.filter { services.contains($0.value) }.keys)
    }

    /// Watchlist titles with provider names normalized, for display.
    var titles: [Title] {
        Planning.prepare(services: services, watchlist: watchlist).1
    }
}

extension SavedState {
    /// A new user: every service we know, none subscribed, an empty
    /// watchlist, and onboarding still to do.
    static var newUser: SavedState {
        var state = sample
        state.services = state.services.map { service in
            var s = service
            s.current = false
            s.renews = nil
            s.billedThrough = nil
            return s
        }
        state.watchlist = []
        state.hasAmazonPrime = false
        state.budget = 40_00
        state.hasCompletedOnboarding = false
        return state
    }

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
