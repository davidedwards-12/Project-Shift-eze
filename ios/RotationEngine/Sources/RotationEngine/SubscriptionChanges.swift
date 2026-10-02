/// Something the user actually did to a subscription: the record of a plan
/// action marked done. Kept as history (actual savings are worked out from it)
/// and so the change can be undone.
public struct SubscriptionChange: Codable, Hashable, Sendable, Identifiable {
    public enum Kind: String, Codable, Sendable {
        case cancelled, started
    }

    /// The action's id ("cancel-Netflix-2026-10-22").
    public var id: String
    public var kind: Kind
    public var service: String
    /// The day the user marked it done.
    public var doneOn: CalendarDate
    /// Cancelled: paid up until this date (the renewal it was cancelled
    /// before). Started: the first billing date.
    public var effectiveOn: CalendarDate
    /// How the service was set up before, so Undo can put it back.
    public var previous: Previous

    /// The subscription fields a change touches.
    public struct Previous: Codable, Hashable, Sendable {
        public var current: Bool
        public var renews: Int?
        public var billedThrough: String?

        public init(current: Bool, renews: Int?, billedThrough: String?) {
            self.current = current
            self.renews = renews
            self.billedThrough = billedThrough
        }
    }

    public init(id: String, kind: Kind, service: String, doneOn: CalendarDate,
                effectiveOn: CalendarDate, previous: Previous) {
        self.id = id
        self.kind = kind
        self.service = service
        self.doneOn = doneOn
        self.effectiveOn = effectiveOn
        self.previous = previous
    }
}

public enum SubscriptionChanges {
    /// Update `services` for a plan action the user has done, and return the
    /// record of it. A cancel stops the service counting as current; a start
    /// or restart makes it current, renewing on the day it was done. Nil for
    /// keeps (nothing to do) and services that aren't in the list.
    public static func apply(_ action: Action, on today: CalendarDate, to services: inout [Service]) -> SubscriptionChange? {
        guard action.kind != .keep,
              let index = services.firstIndex(where: { $0.name == action.service }) else { return nil }
        let before = services[index]
        let previous = SubscriptionChange.Previous(current: before.current, renews: before.renews,
                                                   billedThrough: before.billedThrough)
        let kind: SubscriptionChange.Kind
        let effectiveOn: CalendarDate
        switch action.kind {
        case .cancel:
            services[index].current = false
            kind = .cancelled
            effectiveOn = action.date
        case .start, .restart:
            services[index].current = true
            services[index].renews = today.day
            kind = .started
            effectiveOn = today
        case .keep:
            return nil
        }
        return SubscriptionChange(id: action.id, kind: kind, service: action.service,
                                  doneOn: today, effectiveOn: effectiveOn, previous: previous)
    }

    /// Put the service back the way it was before `change`. Only the fields
    /// the change touched are restored, so later edits (e.g. a new price) stay.
    public static func undo(_ change: SubscriptionChange, in services: inout [Service]) {
        guard let index = services.firstIndex(where: { $0.name == change.service }) else { return }
        services[index].current = change.previous.current
        services[index].renews = change.previous.renews
        services[index].billedThrough = change.previous.billedThrough
    }
}
