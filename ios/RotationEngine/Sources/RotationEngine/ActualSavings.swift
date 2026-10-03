/// What the user was paying for when they started using the app: the
/// "without the app" side of actual savings. A snapshot, editable later.
public struct Baseline: Codable, Hashable, Sendable {
    public struct Entry: Codable, Hashable, Sendable {
        public var service: String
        public var price: Cents
        /// Day of the month it would bill.
        public var billingDay: Int

        public init(service: String, price: Cents, billingDay: Int) {
            self.service = service
            self.price = price
            self.billingDay = billingDay
        }
    }

    /// Savings are counted from this day.
    public var since: CalendarDate
    public var entries: [Entry]

    public init(since: CalendarDate, entries: [Entry]) {
        self.since = since
        self.entries = entries
    }

    /// The services currently paid for, as of `since`.
    public init(services: [Service], since: CalendarDate) {
        self.init(since: since, entries: services.filter(\.current).map(Entry.init(service:)))
    }

    public var monthly: Cents { entries.reduce(0) { $0 + $1.price } }

    public func contains(_ service: String) -> Bool { entries.contains { $0.service == service } }
}

extension Baseline.Entry {
    public init(service: Service) {
        self.init(service: service.name, price: service.price, billingDay: service.renews ?? 1)
    }
}

/// One billing charge, real or "would have been".
public struct Charge: Hashable, Sendable {
    public var service: String
    public var date: CalendarDate
    public var amount: Cents
}

/// Money actually saved: what the baseline subscriptions would have charged
/// versus what the user was really charged, both counted on billing days from
/// `baseline.since` up to today. Rotated-in services are real charges, so
/// they count against savings.
///
/// Simplification: charges use each service's current price.
public enum ActualSavings {
    public struct Totals: Equatable, Sendable {
        /// What the baseline subscriptions would have charged.
        public var withoutApp: Cents
        /// What was actually charged.
        public var actual: Cents
        /// Negative when the user spent more than before.
        public var saved: Cents { withoutApp - actual }
    }

    public struct Summary: Equatable, Sendable {
        public var thisMonth: Totals
        public var thisYear: Totals
        public var allTime: Totals
        public var since: CalendarDate
    }

    public static func summary(
        baseline: Baseline,
        services: [Service],
        changes: [SubscriptionChange],
        today: CalendarDate
    ) -> Summary {
        let without = baselineCharges(baseline, through: today)
        let actual = actualCharges(services: services, changes: changes, since: baseline.since, through: today)
        func totals(_ include: (CalendarDate) -> Bool) -> Totals {
            Totals(withoutApp: without.filter { include($0.date) }.reduce(0) { $0 + $1.amount },
                   actual: actual.filter { include($0.date) }.reduce(0) { $0 + $1.amount })
        }
        return Summary(
            thisMonth: totals { $0.year == today.year && $0.month == today.month },
            thisYear: totals { $0.year == today.year },
            allTime: totals { _ in true },
            since: baseline.since
        )
    }

    /// What the baseline subscriptions would have charged from `since`
    /// through `today`.
    public static func baselineCharges(_ baseline: Baseline, through today: CalendarDate) -> [Charge] {
        baseline.entries.flatMap { entry in
            charges(service: entry.service, price: entry.price, billingDay: entry.billingDay,
                    from: baseline.since, until: nil, through: today)
        }
    }

    /// What the user was really charged from `since` through `today`, worked
    /// out from their subscriptions now and the changes they made.
    public static func actualCharges(
        services: [Service],
        changes: [SubscriptionChange],
        since: CalendarDate,
        through today: CalendarDate
    ) -> [Charge] {
        let relevant = changes.filter { $0.effectiveOn >= since }.sorted { $0.effectiveOn < $1.effectiveOn }
        return services.flatMap { service -> [Charge] in
            let own = relevant.filter { $0.service == service.name }
            // Rewind to how the subscription was set up at `since`: the
            // earliest relevant change remembers the settings before it.
            let initial = own.first?.previous
            var active = initial?.current ?? service.current
            var billingDay = (initial.map { $0.renews } ?? service.renews) ?? 1
            var from = since
            var charges: [Charge] = []
            for change in own {
                switch change.kind {
                case .cancelled where active:
                    // Paid up until the renewal it was cancelled before.
                    charges += Self.charges(service: service.name, price: service.price, billingDay: billingDay,
                                            from: from, until: change.effectiveOn, through: today)
                    active = false
                case .started where !active:
                    active = true
                    billingDay = change.effectiveOn.day
                    from = change.effectiveOn
                default:
                    break
                }
            }
            if active {
                charges += Self.charges(service: service.name, price: service.price, billingDay: billingDay,
                                        from: from, until: nil, through: today)
            }
            return charges
        }
    }

    /// Monthly charges on `billingDay` (clamped to short months) on dates in
    /// `from ..< until` that are on or before `today`.
    static func charges(
        service: String, price: Cents, billingDay: Int,
        from: CalendarDate, until: CalendarDate?, through today: CalendarDate
    ) -> [Charge] {
        var result: [Charge] = []
        var offset = 0
        while true {
            let date = from.onDay(billingDay, monthsLater: offset)
            offset += 1
            if date > today { break }
            if let until, date >= until { break }
            if date >= from { result.append(Charge(service: service, date: date, amount: price)) }
        }
        return result
    }
}
