import Foundation
import Testing
@testable import TMDB

/// A client whose network calls return `body` with `status`, recording requests.
final class StubFetch: @unchecked Sendable {
    var requests: [URLRequest] = []
    let status: Int
    let body: String

    init(status: Int = 200, body: String) {
        self.status = status
        self.body = body
    }

    func client(token: String = "eyJtest") -> TMDBClient {
        TMDBClient(token: token) { request in
            self.requests.append(request)
            let response = HTTPURLResponse(url: request.url!, statusCode: self.status, httpVersion: nil, headerFields: nil)!
            return (Data(self.body.utf8), response)
        }
    }
}

let searchJSON = """
{"results": [
  {"id": 66732, "media_type": "tv", "name": "Stranger Things", "first_air_date": "2016-07-15", "poster_path": "/st.jpg"},
  {"id": 74, "media_type": "movie", "title": "War of the Worlds", "release_date": "2005-06-28", "poster_path": null},
  {"id": 31, "media_type": "person", "name": "Tom Hanks"},
  {"id": 9, "media_type": "movie", "title": "Untitled Project", "release_date": ""}
]}
"""

let providersJSON = """
{"id": 66732, "results": {
  "US": {
    "flatrate": [{"provider_name": "Netflix"}, {"provider_name": "Netflix Standard with Ads"}],
    "free": [{"provider_name": "Tubi TV"}],
    "ads": [{"provider_name": "The Roku Channel"}],
    "rent": [{"provider_name": "Apple TV Store"}]
  },
  "GB": {"flatrate": [{"provider_name": "Channel 4"}]}
}}
"""

@Suite struct Searching {
    @Test func keepsMoviesAndShowsAndParsesThem() async throws {
        let results = try await StubFetch(body: searchJSON).client().search("x")
        #expect(results.map(\.title) == ["Stranger Things", "War of the Worlds", "Untitled Project"])
        #expect(results[0].id == "tmdb:tv:66732")
        #expect(results[0].year == "2016")
        #expect(results[0].posterURL()?.absoluteString == "https://image.tmdb.org/t/p/w154/st.jpg")
        #expect(results[1].posterURL() == nil)
        #expect(results[2].year == nil)
    }

    @Test func readAccessTokensGoInTheHeader() async throws {
        let stub = StubFetch(body: searchJSON)
        _ = try await stub.client(token: "eyJabc").search("Andor")
        let request = try #require(stub.requests.first)
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer eyJabc")
        #expect(request.url?.absoluteString.contains("api_key") == false)
        #expect(request.url?.path() == "/3/search/multi")
        #expect(request.url?.query()?.contains("query=Andor") == true)
    }

    @Test func v3KeysGoInTheQuery() async throws {
        let stub = StubFetch(body: searchJSON)
        _ = try await stub.client(token: "abc123").search("Andor")
        let request = try #require(stub.requests.first)
        #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
        #expect(request.url?.query()?.contains("api_key=abc123") == true)
    }
}

@Suite struct WhereItStreams {
    let stranger = SearchResult(tmdbID: 66732, mediaType: .tv, title: "Stranger Things", year: "2016", posterPath: nil)

    @Test func subscriptionAndFreeProvidersForTheRegion() async throws {
        let stub = StubFetch(body: providersJSON)
        let providers = try await stub.client().providers(for: stranger)
        #expect(providers == Providers(subscription: ["Netflix", "Netflix Standard with Ads"],
                                       free: ["Tubi TV", "The Roku Channel"]))
        #expect(stub.requests.first?.url?.path() == "/3/tv/66732/watch/providers")
    }

    @Test func noListingForTheRegionIsEmpty() async throws {
        let providers = try await StubFetch(body: #"{"results": {}}"#).client().providers(for: stranger)
        #expect(providers == Providers(subscription: [], free: []))
    }

    @Test func watchlistEntryUsesTheTMDBId() {
        let entry = stranger.watchlistEntry(providers: Providers(subscription: ["Netflix"], free: ["Tubi TV"]))
        #expect(entry.id == "tmdb:tv:66732")
        #expect(entry.title == "Stranger Things")
        #expect(entry.services == ["Netflix"])
        #expect(entry.free == ["Tubi TV"])
    }
}

@Suite struct Failures {
    @Test func badKeyIsUnauthorized() async {
        await #expect(throws: TMDBError.unauthorized) {
            try await StubFetch(status: 401, body: "{}").client().search("x")
        }
    }

    @Test func serverErrorsKeepTheStatus() async {
        await #expect(throws: TMDBError.http(503)) {
            try await StubFetch(status: 503, body: "").client().search("x")
        }
    }

    @Test func garbageIsUnreadable() async {
        await #expect(throws: TMDBError.unreadable) {
            try await StubFetch(body: "<html>").client().search("x")
        }
    }

    @Test func noConnectionIsNetwork() async {
        let client = TMDBClient(token: "eyJ") { _ in throw URLError(.notConnectedToInternet) }
        await #expect(throws: TMDBError.network) { try await client.search("x") }
    }
}
