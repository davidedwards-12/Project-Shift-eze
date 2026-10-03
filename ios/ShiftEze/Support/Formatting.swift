import Foundation
import RotationEngine

extension Cents {
    /// "$24.99"
    var money: String { (Decimal(self) / 100).formatted(.currency(code: "USD")) }
}

extension Double {
    /// A cents amount as money: 6297.4 → "$62.97"
    var centsAsMoney: String { (self / 100).formatted(.currency(code: "USD")) }

    /// A cents amount rounded to whole dollars, for estimates: 67964.0 → "$680"
    var centsAsWholeDollars: String {
        (self / 100).formatted(.currency(code: "USD").precision(.fractionLength(0)))
    }
}

extension CalendarDate {
    static var today: CalendarDate {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: .now)
        return CalendarDate(c.year!, c.month!, c.day!)
    }

    var date: Date {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: day))!
    }

    /// "October 2026"
    var monthAndYear: String { date.formatted(.dateTime.month(.wide).year()) }

    /// "Oct 22"
    var short: String { date.formatted(.dateTime.month(.abbreviated).day()) }
}

extension Int {
    /// 1 → "1st", 22 → "22nd"
    var ordinal: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .ordinal
        return formatter.string(from: NSNumber(value: self)) ?? "\(self)"
    }
}
