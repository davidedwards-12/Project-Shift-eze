/// A notification to show ahead of an action. The app turns it into words
/// and picks the time of day
public struct Reminder: Hashable, Sendable, Identifiable {
    public var action: Action
    /// The day to show it
    public var day: CalendarDate
    /// Watchlist titles a Start/Restart is for (empty for cancels)
    public var titles: [String]
    
    /// The action's id, so marking the action done drops its reminder
    public var id: String { action.id }
}

public enum Reminders {
    /// iOS keeps at most 64 pending local notifications per app; leave room
    public static let limit = 60
    /// Cancels are reminded this many days early, so there's time to do it
    /// before the renewal
    public static let cancelLeadDays = 2
    
    /// Reminders for the plan's upcoming actions, soonest first. Keeps need no reminder; actions already in the past or marked
    /// done are skipped. A cancel due within `cancelLeadDays` is reminded today
    public static func make(plan: RotationPlan, today: CalendarDate, done: Set<String> = []) -> [Reminder] {
        let reminders = plan.actions.compactMap { action -> Reminder? in
            guard action.date >= today, !done.contains(action.id) else { return nil }
            switch action.kind {
            case .keep:
                return nil
            case .cancel:
                let day = max(action.date.adding(days: -cancelLeadDays), today)
                return Reminder(action: action, day: day, titles: [])
            case .start, .restart:
                let titles = plan.paid.filter { plan.cover.assignment[$0.id] == action.service}.map(\.name)
                return Reminder(action: action, day: action.date, titles: titles)
            }
        }
        return Array(reminders.sorted { ($0.day, $0.id) < ($1.day, $1.id) }.prefix(limit))
    }
}
