/// A complete plan for one watchlist and budget: the whole pipeline in one call.
public struct RotationPlan: Sendable {
    /// Paid services per month, from `start`.
    public var months: [Month]
    public var start: CalendarDate
    /// Which service each paid title is watched on.
    public var cover: Planning.Cover
    public var catalog: Catalog
    /// Titles the plan pays for, in watchlist order.
    public var paid: [Title]
    /// Titles covered by a membership the user has (e.g. Prime Video).
    public var included: [Title]
    /// Titles free on a trusted service, and where to watch them.
    public var free: [Title]
    public var freePlacement: Planning.FreePlacement
    /// Paid titles that are also free with a library card.
    public var library: [Title]
    /// Titles on no tracked service at all.
    public var unavailable: [Title]
    public var actions: [Action]
    public var savings: Savings

    public enum Failure: Error, Equatable {
        /// Some title is only on services priced above the budget.
        case budgetTooLow
    }

    public static func make(
        services: [Service],
        watchlist: [WatchlistEntry],
        memberships: [String: Bool] = [:],
        budget: Cents,
        start: CalendarDate,
        today: CalendarDate,
        links: ManagementLinks = .bundled
    ) throws(Failure) -> RotationPlan {
        let (catalog, titles) = Planning.prepare(services: services, watchlist: watchlist, memberships: memberships)
        let (included, rest) = Planning.splitIncluded(titles)
        let (free, paidOrNone) = Planning.splitFree(rest)
        let paid = paidOrNone.filter { !$0.services.isEmpty }

        let cover: Planning.Cover
        if paid.isEmpty {
            cover = Planning.Cover(cost: 0, assignment: [:], need: [:], services: [])
        } else {
            guard let found = Planning.cheapestCover(paid, catalog: catalog, budget: budget) else {
                throw .budgetTooLow
            }
            cover = found
        }
        let months = Planning.schedule(cover, catalog: catalog, budget: budget)

        return RotationPlan(
            months: months,
            start: start,
            cover: cover,
            catalog: catalog,
            paid: paid,
            included: included,
            free: free,
            freePlacement: Planning.placeFree(free, months: months, catalog: catalog),
            library: paid.filter { !$0.library.isEmpty },
            unavailable: paidOrNone.filter { $0.services.isEmpty },
            actions: Actions.plan(catalog: catalog, months: months, start: start, today: today, links: links),
            savings: Savings(catalog: catalog, cover: cover, months: months)
        )
    }

    /// First day of month `index` of the plan.
    public func date(ofMonth index: Int) -> CalendarDate { start.onDay(1, monthsLater: index) }

    /// A watchlist title by id, from any section of the plan.
    public func title(id: String) -> Title? {
        (paid + included + free + unavailable).first { $0.id == id }
    }

    /// Titles watched on `service` in month `index`: the ones it's paid for,
    /// then free titles placed there (`alsoFree` true).
    public func titles(in index: Int, on service: String) -> [(id: String, name: String, alsoFree: Bool)] {
        let paidHere = paid.filter { cover.assignment[$0.id] == service }
            .map { (id: $0.id, name: $0.name, alsoFree: false) }
        let freeHere = free.filter { freePlacement.inPlan[$0.id] == .init(month: index, service: service) }
            .map { (id: $0.id, name: $0.name, alsoFree: true) }
        return paidHere + freeHere
    }
}
