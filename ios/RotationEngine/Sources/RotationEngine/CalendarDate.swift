/// A plain calendar date. Billing is by day of month, so no times or time zones.
public struct CalendarDate: Hashable, Comparable, Sendable, CustomStringConvertible {
    public var year: Int
    public var month: Int
    public var day: Int

    public init(_ year: Int, _ month: Int, _ day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    public static func < (a: CalendarDate, b: CalendarDate) -> Bool {
        (a.year, a.month, a.day) < (b.year, b.month, b.day)
    }

    public var description: String {
        "\(year)-\(month < 10 ? "0" : "")\(month)-\(day < 10 ? "0" : "")\(day)"
    }

    /// `day` of the month `offset` months after this date's month, clamped to
    /// the month's length (day 31 in February → the 28th or 29th).
    public func onDay(_ day: Int, monthsLater offset: Int) -> CalendarDate {
        let index = year * 12 + (month - 1) + offset
        let y = index >= 0 ? index / 12 : (index - 11) / 12
        let m = index - y * 12 + 1
        return CalendarDate(y, m, min(day, Self.daysIn(year: y, month: m)))
    }

    /// The first of the following month.
    public var firstOfNextMonth: CalendarDate { onDay(1, monthsLater: 1) }
    
    public func adding(days: Int) -> CalendarDate {
        CalendarDate(dayNumber: dayNumber + days)
    }
    
    init(dayNumber: Int) {
        let z = dayNumber + 719_468
        let era = (z >= 0 ? z : z - 146_096) / 146_097
        let dayOfEra = z - era * 146_097
        let yearOfEra = (dayOfEra - dayOfEra / 1460 + dayOfEra / 36_524 - dayOfEra / 146_096) / 365
        let dayOfYear = dayOfEra - (365 * yearOfEra + yearOfEra / 4 - yearOfEra / 100)
        let mp = (5 * dayOfYear + 2) / 153
        let day = dayOfYear - (153 * mp + 2) / 5 + 1
        let month = mp < 10 ? mp + 3 : mp - 9
        self.init(yearOfEra + era * 400 + (month <= 2 ? 1 : 0), month, day)
    }

    /// Whole days from this date to `other` (negative if `other` is earlier).
    public func days(to other: CalendarDate) -> Int {
        other.dayNumber - dayNumber
    }

    /// Days since 1970-01-01 (proleptic Gregorian calendar).
    var dayNumber: Int {
        let y = month <= 2 ? year - 1 : year
        let era = (y >= 0 ? y : y - 399) / 400
        let yearOfEra = y - era * 400
        let dayOfYear = (153 * (month + (month > 2 ? -3 : 9)) + 2) / 5 + day - 1
        let dayOfEra = yearOfEra * 365 + yearOfEra / 4 - yearOfEra / 100 + dayOfYear
        return era * 146_097 + dayOfEra - 719_468
    }

    static func daysIn(year: Int, month: Int) -> Int {
        switch month {
        case 2:
            let leap = (year % 4 == 0 && year % 100 != 0) || year % 400 == 0
            return leap ? 29 : 28
        case 4, 6, 9, 11:
            return 30
        default:
            return 31
        }
    }
}

/// Saved as "2026-10-02".
extension CalendarDate: Codable {
    public init(from decoder: Decoder) throws {
        let text = try decoder.singleValueContainer().decode(String.self)
        let parts = text.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3, (1...12).contains(parts[1]), (1...31).contains(parts[2]) else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Not a date: \(text)"))
        }
        self.init(parts[0], parts[1], parts[2])
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(description)
    }
}
