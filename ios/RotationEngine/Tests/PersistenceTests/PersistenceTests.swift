import Foundation
import Testing
import RotationEngine
@testable import Persistence

/// A store in a fresh temp folder whose name has a space, like the real
/// "Application Support".
func tempStore() -> Store {
    Store(url: FileManager.default.temporaryDirectory
        .appending(path: "\(UUID().uuidString) Application Support")
        .appending(path: "state.json"))
}

let sampleState = SavedState(
    services: [Service(name: "Netflix", price: 2499, current: true, renews: 22, billedThrough: "Apple")],
    watchlist: [WatchlistEntry(id: "st", title: "Stranger Things", services: ["Netflix"])],
    hasAmazonPrime: true,
    budget: 40_00,
    hasCompletedOnboarding: true,
    changes: [],
    baseline: nil
)

@Suite struct StoreFile {
    @Test func nothingSavedYetIsEmpty() {
        #expect(tempStore().load() == .empty)
    }

    @Test func savedFileInAFolderWithASpaceIsFound() throws {
        let store = tempStore()
        #expect(store.url.path(percentEncoded: false).contains(" "))
        try store.save(sampleState)
        #expect(store.load() != .empty)
    }

    @Test func saveThenLoadRoundTrips() throws {
        let store = tempStore()
        try store.save(sampleState)
        #expect(store.load() == .loaded(sampleState))
    }

    @Test func unreadableFileIsMovedAsideNotOverwritten() throws {
        let store = tempStore()
        try store.save(sampleState)
        try Data("not json".utf8).write(to: store.url)

        guard case .damaged(let movedTo?) = store.load() else {
            Issue.record("expected .damaged with a moved copy")
            return
        }
        #expect(!FileManager.default.fileExists(atPath: store.url.path(percentEncoded: false)))
        #expect(try String(contentsOf: movedTo, encoding: .utf8) == "not json")
    }
}

@Suite struct Onboarding {
    @Test func filesSavedBeforeOnboardingCountAsDone() throws {
        let store = tempStore()
        try store.save(sampleState)
        // Strip the flag to mimic a file written by an older version.
        var json = try JSONSerialization.jsonObject(with: Data(contentsOf: store.url)) as! [String: Any]
        json.removeValue(forKey: "hasCompletedOnboarding")
        try JSONSerialization.data(withJSONObject: json).write(to: store.url)

        guard case .loaded(let state) = store.load() else {
            Issue.record("expected .loaded")
            return
        }
        #expect(state.hasCompletedOnboarding)
    }

    @Test func changesRoundTripAndDefaultToEmpty() throws {
        var state = sampleState
        state.changes = [SubscriptionChange(
            id: "cancel-Netflix-2026-10-22", kind: .cancelled, service: "Netflix",
            doneOn: CalendarDate(2026, 10, 20), effectiveOn: CalendarDate(2026, 10, 22),
            previous: .init(current: true, renews: 22, billedThrough: "Apple"))]
        let store = tempStore()
        try store.save(state)
        #expect(store.load() == .loaded(state))
        #expect(sampleState.changes.isEmpty)
    }

    @Test func baselineRoundTripsAndIsMissingInOlderFiles() throws {
        var state = sampleState
        #expect(state.baseline == nil)
        state.baseline = Baseline(since: CalendarDate(2026, 10, 2),
                                  entries: [.init(service: "Netflix", price: 2499, billingDay: 22)])
        let store = tempStore()
        try store.save(state)
        #expect(store.load() == .loaded(state))
    }

    @Test func oldDoneActionsListIsIgnored() throws {
        let store = tempStore()
        try store.save(sampleState)
        var json = try JSONSerialization.jsonObject(with: Data(contentsOf: store.url)) as! [String: Any]
        json.removeValue(forKey: "changes")
        json["doneActions"] = ["cancel-Netflix-2026-10-22"]
        try JSONSerialization.data(withJSONObject: json).write(to: store.url)
        #expect(store.load() == .loaded(sampleState))
    }

    @Test func notOnboardedIsSavedAndLoaded() throws {
        var state = sampleState
        state.hasCompletedOnboarding = false
        let store = tempStore()
        try store.save(state)
        #expect(store.load() == .loaded(state))
    }
}

@Suite struct Sanitizing {
    @Test func badValuesAreFixed() {
        var state = sampleState
        state.services[0].price = -500
        state.services[0].renews = 40
        state.watchlist[0].months = 0
        state.budget = 0
        let fixed = state.sanitized()
        #expect(fixed.services[0].price == 0)
        #expect(fixed.services[0].renews == 31)
        #expect(fixed.watchlist[0].months == 1)
        #expect(fixed.budget == 1_00)
    }

    @Test func duplicateIdsAreReplaced() {
        var state = sampleState
        state.watchlist.append(state.watchlist[0])
        let ids = state.sanitized().watchlist.map(\.id)
        #expect(ids[0] == "st")
        #expect(Set(ids).count == 2)
    }

    @Test func goodDataIsUnchanged() {
        #expect(sampleState.sanitized() == sampleState)
    }
}
