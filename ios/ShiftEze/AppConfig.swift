import Foundation
import TMDB

/// Build-time configuration, from Config.xcconfig via Info.plist.
enum AppConfig {
    /// TMDB key from Secrets.xcconfig, or nil when it isn't set up.
    /// Development only: see Config.xcconfig.
    static var tmdbToken: String? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: "TMDBAPIKey") as? String else { return nil }
        let token = value.trimmingCharacters(in: .whitespaces)
        return token.isEmpty || token.hasPrefix("$(") ? nil : token
    }

    static var tmdbClient: TMDBClient? { tmdbToken.map { TMDBClient(token: $0) } }
}
