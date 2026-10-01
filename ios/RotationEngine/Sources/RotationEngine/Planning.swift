/// Planning: which services cover the watchlist, and in which months.
///
/// Each title is watched on one service that carries it, for `months`
/// consecutive months. `cheapestCover` picks the lowest-cost set of services
/// covering every title; `schedule` packs them into months under the budget,
/// highest-priority titles (earliest in the watchlist) first.
public enum Planning {
    /// TMDB's "free" category is noisy (e.g. "Amazon Prime Video Free with Ads"
    /// on Prime originals). Only these count as genuinely free.
    public static let trustedFree: Set<String> = [
        "tubi tv", "the roku channel", "pluto tv", "plex", "plex channel", "youtube free", "fawesome",
    ]
    /// Free, but only with a library card: shown as an option, never relied on.
    public static let library: Set<String> = ["kanopy", "hoopla"]

    /// Normalize raw watchlist entries against the catalog.
    ///
    /// Provider names map to services via names and aliases; untracked ones
    /// (e.g. cable VOD) are dropped. A service whose `includedWith` membership
    /// the user has makes its titles `included`.
    public static func prepare(
        services: [Service],
        watchlist: [WatchlistEntry],
        memberships: [String: Bool] = [:]
    ) -> (Catalog, [Title]) {
        let includedServices = Set(services.filter { s in s.includedWith.map { memberships[$0] == true } ?? false }.map(\.name))
        var lookup: [String: String] = [:]
        for s in services {
            for n in [s.name] + s.aliases { lookup[n.lowercased()] = s.name }
        }

        let titles = watchlist.map { entry -> Title in
            let on = Set(entry.services.compactMap { lookup[$0.lowercased()] }).sorted()
            let free = entry.free ?? []
            return Title(
                id: entry.id,
                name: entry.title,
                services: on,
                free: free.filter { trustedFree.contains($0.lowercased()) },
                library: free.filter { library.contains($0.lowercased()) },
                included: on.filter { includedServices.contains($0) },
                months: entry.months ?? 1
            )
        }
        return (Catalog(services), titles)
    }

    /// (included, rest): titles covered by a membership the user already has.
    public static func splitIncluded(_ titles: [Title]) -> (included: [Title], rest: [Title]) {
        (titles.filter { !$0.included.isEmpty }, titles.filter { $0.included.isEmpty })
    }

    /// (free, paid): titles watchable free need no subscription at all.
    public static func splitFree(_ titles: [Title]) -> (free: [Title], paid: [Title]) {
        (titles.filter { !$0.free.isEmpty }, titles.filter { $0.free.isEmpty })
    }

    /// The chosen services and which one each title is watched on.
    public struct Cover: Sendable {
        public var cost: Cents
        /// Title id → service it's watched on.
        public var assignment: [String: String]
        /// Service → months it must stay active, for services in `services`.
        public var need: [String: Int]
        /// The chosen services, in watchlist priority order.
        public var services: [String]
    }

    /// Exhaustively find the lowest-cost set of services covering every title
    /// (fine for ~15 services). Nil when some title is only on services priced
    /// above the budget.
    public static func cheapestCover(_ titles: [Title], catalog: Catalog, budget: Cents) -> Cover? {
        let names = Set(titles.flatMap(\.services)).sorted()
        var best: Cover?
        for size in 1...max(names.count, 1) where size <= names.count {
            for combo in combinations(names, size) {
                if combo.contains(where: { catalog[$0].price > budget }) { continue }
                guard let assignment = assign(titles, chosen: Set(combo), catalog: catalog) else { continue }
                let (need, order) = durations(titles, assignment: assignment)
                let cost = need.reduce(0) { $0 + catalog[$1.key].price * $1.value }
                if best == nil || cost < best!.cost {
                    best = Cover(cost: cost, assignment: assignment, need: need, services: order)
                }
            }
        }
        return best
    }

    /// Pack the cover's services into months without exceeding the budget,
    /// in watchlist priority order. A service needing N months gets N
    /// consecutive months.
    public static func schedule(_ cover: Cover, catalog: Catalog, budget: Cents) -> [Month] {
        var months: [Month] = []
        for service in cover.services {
            let price = catalog[service].price
            let span = cover.need[service]!
            var start = 0
            while true {
                while months.count < start + span { months.append(Month()) }
                let window = start..<(start + span)
                if window.allSatisfy({ months[$0].total + price <= budget }) {
                    for i in window { months[i].add(service, price: price) }
                    break
                }
                start += 1
            }
        }
        return months
    }

    /// Where a free title can be watched without ads, if you'll be paying anyway.
    public struct FreePlacement: Equatable, Sendable {
        public struct Spot: Equatable, Sendable {
            public var month: Int
            public var service: String
        }

        /// Title id → earliest planned month with a service that carries it.
        public var inPlan: [String: Spot] = [:]
        /// Title id → a service you pay for now but the plan drops.
        public var onCurrent: [String: String] = [:]
        /// Title ids with no paid option you'll have; watch them free.
        public var freeOnly: [String] = []
    }

    /// Place free titles on a paid service you'll have anyway. Free titles
    /// never add a service or change the plan's cost.
    public static func placeFree(_ free: [Title], months: [Month], catalog: Catalog) -> FreePlacement {
        var result = FreePlacement()
        for t in free {
            let spot = months.indices.lazy.compactMap { i in
                t.services.first(where: { months[i].contains($0) }).map { FreePlacement.Spot(month: i, service: $0) }
            }.first
            if let spot {
                result.inPlan[t.id] = spot
            } else if let current = t.services.first(where: { catalog[$0].current }) {
                result.onCurrent[t.id] = current
            } else {
                result.freeOnly.append(t.id)
            }
        }
        return result
    }

    // MARK: - Helpers

    /// Each title → the cheapest chosen service that carries it, or nil if
    /// some title isn't covered.
    static func assign(_ titles: [Title], chosen: Set<String>, catalog: Catalog) -> [String: String]? {
        var out: [String: String] = [:]
        for t in titles {
            let options = t.services.filter { chosen.contains($0) }
            guard let cheapest = options.min(by: { catalog[$0].price < catalog[$1].price }) else { return nil }
            out[t.id] = cheapest
        }
        return out
    }

    /// Months each service must stay active (the longest title on it), plus
    /// the services in order of the first title that needs them.
    static func durations(_ titles: [Title], assignment: [String: String]) -> ([String: Int], [String]) {
        var need: [String: Int] = [:]
        var order: [String] = []
        for t in titles {
            let s = assignment[t.id]!
            if need[s] == nil { order.append(s) }
            need[s] = max(need[s] ?? 0, t.months)
        }
        return (need, order)
    }

    /// All `size`-element combinations of `items`, in lexicographic order
    /// (matches Python's itertools.combinations, so ties resolve the same way).
    static func combinations(_ items: [String], _ size: Int) -> [[String]] {
        guard size > 0 else { return [[]] }
        guard items.count >= size else { return [] }
        var result: [[String]] = []
        for (i, item) in items.enumerated() {
            for rest in combinations(Array(items[(i + 1)...]), size - 1) {
                result.append([item] + rest)
            }
        }
        return result
    }
}
