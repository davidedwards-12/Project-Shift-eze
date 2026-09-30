import Foundation

/// Where each subscription is cancelled or restarted, by who bills it.
/// Loaded from `management_links.json`; see its `_note` and `source` fields.
public struct ManagementLinks: Decodable, Sendable {
    public struct ServiceEntry: Decodable, Sendable {
        public var manage: String
        public var cancel: String
    }

    public struct Biller: Decodable, Sendable {
        public var web: String
        public var ios: String?
        public var android: String?
        public var aliases: [String]?
    }

    /// A biller that takes payment but doesn't control the subscription
    /// (Roku for Disney+ and Hulu): send the user to the service instead.
    public struct Exception: Decodable, Sendable {
        public var services: [String]
        public var biller: String
        public var use: String
    }

    public var services: [String: ServiceEntry]
    public var billers: [String: Biller]
    public var exceptions: [Exception]

    /// The copy bundled with the package.
    public static let bundled: ManagementLinks = {
        let url = Bundle.module.url(forResource: "management_links", withExtension: "json")!
        return try! JSONDecoder().decode(ManagementLinks.self, from: Data(contentsOf: url))
    }()

    /// URL where this subscription is managed, given who bills it. Unknown
    /// billers fall back to the service's own account page, which names the
    /// biller.
    public func link(service: String, billedThrough biller: String) -> String? {
        var biller = biller
        if exceptions.contains(where: { $0.services.contains(service) && $0.biller == biller && $0.use == "service" }) {
            biller = service
        }
        if let entry = billers[biller], biller != service {
            return entry.web
        }
        if let aliased = billers.values.first(where: { $0.aliases?.contains(biller) == true }) {
            return aliased.web
        }
        return services[service]?.manage
    }
}
