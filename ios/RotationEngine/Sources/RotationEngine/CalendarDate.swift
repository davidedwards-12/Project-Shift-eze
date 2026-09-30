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
