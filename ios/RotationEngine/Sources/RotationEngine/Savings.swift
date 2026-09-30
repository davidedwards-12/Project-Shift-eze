/// A plan's projected savings. A preview only: the app's headline number
/// should be actual savings tracked month by month.
public struct Savings: Equatable, Sendable {
    /// What you pay for now, per month.
    public var baseline: Cents
    /// The plan's total spend.
    public var planned: Cents
    /// Months the plan covers.
    public var months: Int
    /// Services the plan uses that you don't pay for now (display only).
    public var added: [String]

    /// The plan's average spend per month.
    public var averagePerMonth: Double { months == 0 ? 0 : Double(planned) / Double(months) }
    /// Baseline minus the plan's average month.
    public var perMonth: Double { Double(baseline) - averagePerMonth }

    /// Compare the plan with keeping what you pay for now. Conservative on
    /// purpose: it doesn't assume you'd otherwise add every service the
    /// watchlist needs and keep it forever.
    public init(catalog: Catalog, cover: Planning.Cover, months: [Month]) {
        baseline = catalog.services.filter(\.current).reduce(0) { $0 + $1.price }
        planned = months.reduce(0) { $0 + $1.total }
        self.months = months.count
        added = cover.services.filter { !catalog[$0].current }
    }
}
