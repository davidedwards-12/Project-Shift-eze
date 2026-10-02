import Foundation

/// Money in whole cents, so prices and budgets compare exactly.
public typealias Cents = Int

/// A streaming service the user pays for now, or that a plan might use.
public struct Service: Hashable, Sendable {
    public var name: String
    public var price: Cents
    /// The user pays for it today; part of the no-rotation baseline.
    public var current: Bool
    /// Day of the month it bills, for current services.
    public var renews: Int?
    /// Who controls the subscription (Apple, Roku, the service itself…).
    public var billedThrough: String?
    /// A membership that makes it free, e.g. "amazon_prime" for Prime Video.
    public var includedWith: String?
    /// Other names TMDB uses for it ("Netflix Standard with Ads").
    public var aliases: [String]

    public init(
        name: String,
        price: Cents,
        current: Bool = false,
        renews: Int? = nil,
        billedThrough: String? = nil,
        includedWith: String? = nil,
        aliases: [String] = []
    ) {
        self.name = name
        self.price = price
        self.current = current
        self.renews = renews
        self.billedThrough = billedThrough
        self.includedWith = includedWith
        self.aliases = aliases
    }
}

extension Service: Codable {
    enum CodingKeys: String, CodingKey {
        case name, price, current, renews, aliases
        case billedThrough = "billed_through"
        case includedWith = "included_with"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = try c.decode(String.self, forKey: .name)
        // JSON carries dollars (24.99); store cents.
        price = Cents((try c.decode(Double.self, forKey: .price) * 100).rounded())
        current = try c.decodeIfPresent(Bool.self, forKey: .current) ?? false
        renews = try c.decodeIfPresent(Int.self, forKey: .renews)
        billedThrough = try c.decodeIfPresent(String.self, forKey: .billedThrough)
        includedWith = try c.decodeIfPresent(String.self, forKey: .includedWith)
        aliases = try c.decodeIfPresent([String].self, forKey: .aliases) ?? []
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(name, forKey: .name)
        try c.encode(Double(price) / 100, forKey: .price)
        try c.encode(current, forKey: .current)
        try c.encodeIfPresent(renews, forKey: .renews)
        try c.encodeIfPresent(billedThrough, forKey: .billedThrough)
        try c.encodeIfPresent(includedWith, forKey: .includedWith)
        try c.encode(aliases, forKey: .aliases)
    }
}

/// A watchlist line as it comes from TMDB: provider names are raw.
public struct WatchlistEntry: Hashable, Sendable {
    /// Stable identity, so two titles with the same name don't clash.
    /// Defaults to the title for data saved before IDs existed.
    public var id: String
    public var title: String
    public var services: [String]
    public var free: [String]?
    public var months: Int?
    /// When `services` and `free` were last fetched from TMDB. Nil for titles
    /// that never were (e.g. the bundled sample data).
    public var checkedOn: CalendarDate?
    /// Services (normalized names) the user says this title isn't actually
    /// on, whatever TMDB says. The plan ignores them for this title.
    public var notOn: [String]?

    public init(
        id: String? = nil,
        title: String,
        services: [String],
        free: [String]? = nil,
        months: Int? = nil,
        checkedOn: CalendarDate? = nil,
        notOn: [String]? = nil
    ) {
        self.id = id ?? title
        self.title = title
        self.services = services
        self.free = free
        self.months = months
        self.checkedOn = checkedOn
        self.notOn = notOn
    }
}

extension WatchlistEntry: Codable {
    enum CodingKeys: String, CodingKey { case id, title, services, free, months, checkedOn, notOn }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        title = try c.decode(String.self, forKey: .title)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? title
        services = try c.decodeIfPresent([String].self, forKey: .services) ?? []
        free = try c.decodeIfPresent([String].self, forKey: .free)
        months = try c.decodeIfPresent(Int.self, forKey: .months)
        checkedOn = try c.decodeIfPresent(CalendarDate.self, forKey: .checkedOn)
        notOn = try c.decodeIfPresent([String].self, forKey: .notOn)
    }
}

/// A watchlist title after provider names are normalized to services.
public struct Title: Hashable, Sendable {
    /// The watchlist entry's id; plans are keyed by this, not the name.
    public var id: String
    public var name: String
    /// Tracked paid services that carry it, sorted by name.
    public var services: [String]
    /// Trusted free, ad-supported providers (Tubi, The Roku Channel…).
    public var free: [String]
    /// Free with a library card (Kanopy, Hoopla): an option, never relied on.
    public var library: [String]
    /// Services that carry it and are included with a membership the user has.
    public var included: [String]
    /// How many months it takes to watch.
    public var months: Int
    /// When availability was last fetched; nil if never.
    public var checkedOn: CalendarDate? = nil
    /// Services TMDB lists but the user says it isn't on; excluded from
    /// `services`.
    public var notOn: [String] = []
}

/// The services a plan can use, by name, in their original order.
public struct Catalog: Sendable {
    public let services: [Service]
    public let byName: [String: Service]

    public init(_ services: [Service]) {
        self.services = services
        self.byName = Dictionary(services.map { ($0.name, $0) }, uniquingKeysWith: { first, _ in first })
    }

    public subscript(name: String) -> Service { byName[name]! }
}

/// One month of a plan: the services active, in the order they were added.
public struct Month: Hashable, Sendable {
    public private(set) var services: [String] = []
    public private(set) var prices: [String: Cents] = [:]

    public init() {}

    public init(_ pairs: KeyValuePairs<String, Cents>) {
        for (service, price) in pairs { add(service, price: price) }
    }

    public var total: Cents { prices.values.reduce(0, +) }

    public func contains(_ service: String) -> Bool { prices[service] != nil }

    mutating func add(_ service: String, price: Cents) {
        if prices[service] == nil { services.append(service) }
        prices[service] = price
    }
}
