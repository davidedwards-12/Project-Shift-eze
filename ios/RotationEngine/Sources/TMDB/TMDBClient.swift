import Foundation
import RotationEngine

/// Searches TMDB for movies and TV shows and looks up where they stream.
/// Watch-provider data is supplied to TMDB by JustWatch; both need crediting
/// wherever results are shown.
public struct TMDBClient: Sendable {
    public typealias Fetch = @Sendable (URLRequest) async throws -> (Data, URLResponse)

    let token: String
    let region: String
    let fetch: Fetch

    /// `token` is the API Read Access Token (starts with "eyJ") or a v3 API key.
    public init(
        token: String,
        region: String = "US",
        fetch: @escaping Fetch = { try await URLSession.shared.data(for: $0) }
    ) {
        self.token = token
        self.region = region
        self.fetch = fetch
    }

    /// Movies and TV shows matching `query`, best match first.
    public func search(_ query: String) async throws(TMDBError) -> [SearchResult] {
        let response: SearchResponse = try await get("/search/multi", ["query": query, "include_adult": "false"])
        return response.results.compactMap(SearchResult.init)
    }

    /// Where `result` streams in this client's region.
    public func providers(for result: SearchResult) async throws(TMDBError) -> Providers {
        let response: ProvidersResponse = try await get("/\(result.mediaType.rawValue)/\(result.tmdbID)/watch/providers")
        let region = response.results[region]
        let names = { (list: [ProviderJSON]?) in (list ?? []).map(\.providerName) }
        return Providers(
            subscription: names(region?.flatrate),
            free: names(region?.free) + names(region?.ads)
        )
    }

    // MARK: - Requests

    static let base = URL(string: "https://api.themoviedb.org/3")!

    func request(_ path: String, _ query: [String: String] = [:]) -> URLRequest {
        var items = query.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) }
        let bearer = token.hasPrefix("eyJ")
        if !bearer { items.append(URLQueryItem(name: "api_key", value: token)) }
        var url = Self.base.appending(path: path)
        if !items.isEmpty { url.append(queryItems: items) }
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if bearer { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        return request
    }

    private func get<T: Decodable>(_ path: String, _ query: [String: String] = [:]) async throws(TMDBError) -> T {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await fetch(request(path, query))
        } catch {
            throw .network
        }
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw http.statusCode == 401 ? .unauthorized : .http(http.statusCode)
        }
        do {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            return try decoder.decode(T.self, from: data)
        } catch {
            throw .unreadable
        }
    }
}

public enum TMDBError: Error, Equatable, Sendable {
    /// No connection, timeout and the like.
    case network
    /// The key is missing, wrong or revoked.
    case unauthorized
    case http(Int)
    /// TMDB answered with something we couldn't parse.
    case unreadable
}

/// A movie or TV show from search.
public struct SearchResult: Identifiable, Hashable, Sendable {
    public enum MediaType: String, Sendable { case movie, tv }

    public var tmdbID: Int
    public var mediaType: MediaType
    public var title: String
    /// Release or first-air year, when TMDB knows it.
    public var year: String?
    public var posterPath: String?

    public init(tmdbID: Int, mediaType: MediaType, title: String, year: String?, posterPath: String?) {
        self.tmdbID = tmdbID
        self.mediaType = mediaType
        self.title = title
        self.year = year
        self.posterPath = posterPath
    }

    /// Stable across searches, and the watchlist entry id: "tmdb:tv:66732".
    public var id: String { "tmdb:\(mediaType.rawValue):\(tmdbID)" }

    /// TMDB's image CDN; `width` is one of TMDB's sizes (w92, w154, w185…).
    public func posterURL(width: String = "w154") -> URL? {
        posterPath.map { URL(string: "https://image.tmdb.org/t/p/\(width)\($0)")! }
    }

    /// A watchlist entry for this title, with raw provider names (the engine
    /// normalizes them).
    public func watchlistEntry(providers: Providers) -> WatchlistEntry {
        WatchlistEntry(id: id, title: title, services: providers.subscription, free: providers.free)
    }

    init?(_ json: SearchResponse.Result) {
        guard let type = json.mediaType.flatMap(MediaType.init), let title = json.title ?? json.name else { return nil }
        tmdbID = json.id
        mediaType = type
        self.title = title
        let date = json.releaseDate ?? json.firstAirDate ?? ""
        year = date.count >= 4 ? String(date.prefix(4)) : nil
        posterPath = json.posterPath
    }
}

/// Provider names as TMDB reports them.
public struct Providers: Equatable, Sendable {
    /// Included with a subscription ("flatrate").
    public var subscription: [String]
    /// Free, with or without ads. The engine decides which ones to trust.
    public var free: [String]
}

// MARK: - TMDB JSON

struct SearchResponse: Decodable {
    struct Result: Decodable {
        var id: Int
        var mediaType: String?
        var title: String?
        var name: String?
        var releaseDate: String?
        var firstAirDate: String?
        var posterPath: String?
    }

    var results: [Result]
}

struct ProviderJSON: Decodable {
    var providerName: String
}

struct ProvidersResponse: Decodable {
    struct Region: Decodable {
        var flatrate: [ProviderJSON]?
        var free: [ProviderJSON]?
        var ads: [ProviderJSON]?
    }

    var results: [String: Region]
}
