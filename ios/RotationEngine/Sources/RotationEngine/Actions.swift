/// Something the user needs to do, and by when.
public struct Action: Hashable, Sendable {
    public enum Kind: String, Sendable {
        case cancel = "Cancel"
        case keep = "Keep"
        case restart = "Restart"
        case start = "Start"
    }

    public var date: CalendarDate
    public var kind: Kind
    public var service: String
    public var billedThrough: String
    /// Where to do it on the web. Nil for `keep`, which needs nothing.
    public var link: String?
    /// Where to do it on iPhone: an app deep link when the biller has one
    /// (Apple), otherwise the web link. Nil for `keep`.
    public var iosLink: String?

    /// "Cancel Netflix"
    public var title: String { "\(kind.rawValue) \(service)" }
    
    /// Stable across launches, so "done" survives replanning:
    /// "cancel-Netflix-2026-10-22"
    public var id: String { "\(kind.rawValue.lowercased())-\(service)-\(date)"}
}

public enum Actions {
    /// What to keep, cancel, restart and start, and by when.
    ///
    /// Months are calendar months from `start` (month 0). A renewal on day
    /// 1–15 pays for that calendar month; one on day 16+ pays mostly for the
    /// next month, so it's treated as the start of next month's cycle. A
    /// restarted or new service renews on the 1st. Renewals before `today`
    /// are already paid for.
    public static func plan(
        catalog: Catalog,
        months: [Month],
        start: CalendarDate,
        today: CalendarDate,
        links: ManagementLinks = .bundled
    ) -> [Action] {
        var events: [Action] = []
        for s in catalog.services {
            let active = Set(months.indices.filter { months[$0].contains(s.name) })
            if !s.current && active.isEmpty { continue }
            let via = s.billedThrough ?? s.name
            var day = s.current ? (s.renews ?? 1) : 1
            let link = links.link(service: s.name, billedThrough: via)
            let iosLink = links.iosLink(service: s.name, billedThrough: via)
            var subscribed = s.current
            var kept = false

            func add(_ date: CalendarDate, _ kind: Action.Kind) {
                events.append(Action(date: date, kind: kind, service: s.name, billedThrough: via,
                                     link: kind == .keep ? nil : link,
                                     iosLink: kind == .keep ? nil : iosLink))
            }

            for k in 0...months.count {
                let renewal = start.onDay(day, monthsLater: k - (day > 15 ? 1 : 0))
                if renewal < today { continue }  // already paid for
                if subscribed && !active.contains(k) {
                    add(renewal, .cancel)
                    if active.isEmpty || k > active.max()! { break }
                    subscribed = false
                } else if subscribed && !kept {
                    add(renewal, .keep)
                    kept = true
                } else if !subscribed && active.contains(k) {
                    day = 1
                    add(start.onDay(1, monthsLater: k), s.current ? .restart : .start)
                    subscribed = true
                    kept = true
                }
            }
        }
        return events.sorted { ($0.date, $0.title) < ($1.date, $1.title) }
    }
}
