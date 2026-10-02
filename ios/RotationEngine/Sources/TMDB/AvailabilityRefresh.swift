import RotationEngine

/// When saved availability is old enough to fetch again. Streaming catalogs
/// change all the time, so a title added months ago may have moved.
public enum AvailabilityRefresh {
    /// Re-check anything older than this.
    public static let maxAgeDays = 7
    /// Titles the user is about to subscribe for: re-check after a day.
    public static let urgentMaxAgeDays = 1

    /// Ids of the TMDB titles due a re-check: never checked, or checked more
    /// than `maxAgeDays` ago (`urgentMaxAgeDays` for ids in `urgent`).
    /// Titles that didn't come from TMDB can't be re-checked and are skipped.
    public static func due(
        _ watchlist: [WatchlistEntry],
        today: CalendarDate,
        urgent: Set<String> = []
    ) -> [String] {
        watchlist.compactMap { entry in
            guard SearchResult.reference(fromID: entry.id) != nil else { return nil }
            guard let checked = entry.checkedOn else { return entry.id }
            let limit = urgent.contains(entry.id) ? urgentMaxAgeDays : maxAgeDays
            return checked.days(to: today) >= limit ? entry.id : nil
        }
    }
}
