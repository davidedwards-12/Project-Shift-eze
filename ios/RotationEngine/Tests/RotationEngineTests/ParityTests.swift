// The Swift engine must plan exactly like the Python spike. Fixtures/ holds
// copies of spikes/rotation/services.json and watchlist.json, and
// expected_plan.json is the Python engine's output for them (budget $40,
// start October 2026, today Sep 29 2026). Regenerate all three together.

import Foundation
import Testing
@testable import RotationEngine

struct ExpectedPlan: Decodable {
    var budget_cents: Int
    var months: [[[Value]]]
    var assignment: [String: String]
    var actions: [String]
    var included: [String]
    var free_in_plan: [String: [Value]]
    var free_only: [String]
    var baseline_cents: Int
    var added: [String]

    enum Value: Decodable, Equatable {
        case string(String), int(Int)
        init(from decoder: Decoder) throws {
            let c = try decoder.singleValueContainer()
            if let i = try? c.decode(Int.self) { self = .int(i) } else { self = .string(try c.decode(String.self)) }
        }
    }
}

struct ServicesFile: Decodable {
    var memberships: [String: Bool]?
    var services: [Service]
}

struct WatchlistFile: Decodable {
    var titles: [WatchlistEntry]
}

func fixture<T: Decodable>(_ name: String, as: T.Type) throws -> T {
    let url = Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures")!
    return try JSONDecoder().decode(T.self, from: Data(contentsOf: url))
}

@Test func matchesThePythonSpikeOnTheRealWatchlist() throws {
    let config = try fixture("services", as: ServicesFile.self)
    let watchlist = try fixture("watchlist", as: WatchlistFile.self)
    let expected = try fixture("expected_plan", as: ExpectedPlan.self)
    let budget = expected.budget_cents

    let (catalog, all) = Planning.prepare(services: config.services, watchlist: watchlist.titles,
                                          memberships: config.memberships ?? [:])
    let (included, rest) = Planning.splitIncluded(all)
    let (free, paid) = Planning.splitFree(rest)
    let titles = paid.filter { !$0.services.isEmpty }
    let cover = try #require(Planning.cheapestCover(titles, catalog: catalog, budget: budget))
    let months = Planning.schedule(cover, catalog: catalog, budget: budget)
    let placed = Planning.placeFree(free, months: months, catalog: catalog)
    let savings = Savings(catalog: catalog, cover: cover, months: months)
    let actions = Actions.plan(catalog: catalog, months: months, start: start, today: today)

    #expect(months.map { m in m.services.map { [ExpectedPlan.Value.string($0), .int(m.prices[$0]!)] } } == expected.months)
    #expect(cover.assignment == expected.assignment)
    #expect(actions.map { "\($0.date) \($0.title)" } == expected.actions)
    #expect(included.map(\.name) == expected.included)
    #expect(placed.inPlan.mapValues { [ExpectedPlan.Value.int($0.month), .string($0.service)] } == expected.free_in_plan)
    #expect(placed.freeOnly == expected.free_only)
    #expect(savings.baseline == expected.baseline_cents)
    #expect(savings.added == expected.added)
}
