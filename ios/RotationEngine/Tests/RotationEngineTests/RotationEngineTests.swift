// Ported from spikes/rotation/test_rotate.py. These pin down the planning
// rules; keep both in step until the Python spike is retired.

import Foundation
import Testing
@testable import RotationEngine

let start = CalendarDate(2026, 10, 1)  // plan begins October 2026
let today = CalendarDate(2026, 9, 29)

/// Oct–Dec are 2026; Jan onwards 2027.
func d(_ month: Int, _ day: Int) -> CalendarDate {
    CalendarDate(month >= 9 ? 2026 : 2027, month, day)
}

func actions(_ services: [Service], _ months: [Month]) -> [String] {
    Actions.plan(catalog: Catalog(services), months: months, start: start, today: today)
        .map { "\($0.date) \($0.title)" }
}

func line(_ date: CalendarDate, _ title: String) -> String { "\(date) \(title)" }

@Suite struct RenewalActions {
    @Test func lateMonthRenewalIsKeptForNextMonth() {
        // HBO Max renews on the 28th and is needed in November: the Oct 28
        // renewal covers November, so keep it rather than cancel + restart.
        let hbo = Service(name: "HBO Max", price: 1699, current: true, renews: 28)
        #expect(actions([hbo], [Month(), Month(["HBO Max": 1699])])
            == [line(d(10, 28), "Keep HBO Max"), line(d(11, 28), "Cancel HBO Max")])
    }

    @Test func lateMonthRenewalAlreadyCoversFirstMonth() {
        // Netflix renewed Sep 22, which pays for October: cancel before Oct 22.
        let netflix = Service(name: "Netflix", price: 2499, current: true, renews: 22)
        #expect(actions([netflix], [Month(["Netflix": 2499])]) == [line(d(10, 22), "Cancel Netflix")])
    }

    @Test func cancelRestartCancel() {
        let disney = Service(name: "Disney+", price: 1599, current: true, renews: 1)
        #expect(actions([disney], [Month(), Month(["Disney+": 1599]), Month()])
            == [line(d(10, 1), "Cancel Disney+"), line(d(11, 1), "Restart Disney+"), line(d(12, 1), "Cancel Disney+")])
    }

    @Test func newServiceStartsOnTheFirst() {
        let prime = Service(name: "Prime Video", price: 899)
        #expect(actions([prime], [Month(), Month(), Month(["Prime Video": 899])])
            == [line(d(12, 1), "Start Prime Video"), line(d(1, 1), "Cancel Prime Video")])
    }

    @Test func unneededCurrentServiceIsCancelledOnce() {
        let peacock = Service(name: "Peacock", price: 1299, current: true, renews: 15)
        #expect(actions([peacock], [Month(), Month()]) == [line(d(10, 15), "Cancel Peacock")])
    }

    @Test func unneededNonCurrentServiceHasNoActions() {
        #expect(actions([Service(name: "Hulu", price: 1899)], [Month()]).isEmpty)
    }
}

@Suite struct PlanningRules {
    static let services = [
        Service(name: "Netflix", price: 2499, current: true, aliases: ["Netflix Standard with Ads"]),
        Service(name: "Disney+", price: 1599, current: true, aliases: ["Disney Plus"]),
        Service(name: "Hulu", price: 1899),
        Service(name: "Prime Video", price: 899, aliases: ["Amazon Prime Video"]),
    ]
    static let watchlist = [
        WatchlistEntry(title: "Andor", services: ["Disney Plus"]),
        WatchlistEntry(title: "The Bear", services: ["Hulu", "Disney Plus"]),
        WatchlistEntry(title: "Stranger Things", services: ["Netflix Standard with Ads", "Spectrum On Demand"], months: 2),
        WatchlistEntry(title: "Reacher", services: ["Amazon Prime Video"]),
    ]

    func plan(_ budget: Cents) -> (Catalog, Planning.Cover, [Month]) {
        let (catalog, titles) = Planning.prepare(services: Self.services, watchlist: Self.watchlist)
        let cover = Planning.cheapestCover(titles, catalog: catalog, budget: budget)!
        return (catalog, cover, Planning.schedule(cover, catalog: catalog, budget: budget))
    }

    @Test func providerNamesAreNormalizedAndUnknownOnesDropped() {
        let (_, titles) = Planning.prepare(services: Self.services, watchlist: Self.watchlist)
        #expect(titles[2].services == ["Netflix"])  // alias mapped, Spectrum dropped
    }

    @Test func freeTitlesAreKeptOutOfThePlan() {
        let (catalog, titles) = Planning.prepare(services: Self.services, watchlist: Self.watchlist + [
            WatchlistEntry(title: "Before Sunrise", services: [], free: ["Tubi TV", "The Roku Channel"]),
            WatchlistEntry(title: "Tropic Thunder", services: ["Hulu"], free: ["YouTube Free"]),
        ])
        let (free, paid) = Planning.splitFree(titles)
        #expect(free.map(\.name) == ["Before Sunrise", "Tropic Thunder"])
        let cover = Planning.cheapestCover(paid, catalog: catalog, budget: 4000)!
        #expect(cover.need["Hulu"] == nil)  // Tropic Thunder is free, so it doesn't pull Hulu in
    }

    @Test func untrustedAndLibraryFreeListingsStillGetAPaidPlan() {
        let (_, titles) = Planning.prepare(services: Self.services, watchlist: [
            WatchlistEntry(title: "Reacher", services: ["Amazon Prime Video"], free: ["Amazon Prime Video Free with Ads"]),
            WatchlistEntry(title: "Event Horizon", services: ["Hulu"], free: ["Kanopy"]),
        ])
        let (free, paid) = Planning.splitFree(titles)
        #expect(free.isEmpty)
        #expect(paid[1].library == ["Kanopy"])
    }

    @Test func reusesANeededServiceInsteadOfAddingAnother() {
        // The Bear is on Hulu and Disney+; Andor already needs Disney+.
        let (_, cover, _) = plan(4000)
        #expect(cover.assignment["The Bear"] == "Disney+")
        #expect(cover.need["Hulu"] == nil)
    }

    @Test(arguments: [2500, 4000, 6000])
    func monthsNeverExceedBudget(budget: Cents) {
        let (_, _, months) = plan(budget)
        #expect(months.allSatisfy { $0.total <= budget })
    }

    @Test func multiMonthTitleGetsConsecutiveMonths() {
        let (_, _, months) = plan(2500)
        let active = months.indices.filter { months[$0].contains("Netflix") }
        #expect(active.count == 2)
        #expect(active[1] - active[0] == 1)
    }

    @Test func noPlanWhenBudgetIsBelowARequiredService() {
        let (catalog, titles) = Planning.prepare(services: Self.services, watchlist: Self.watchlist)
        #expect(Planning.cheapestCover(titles, catalog: catalog, budget: 1000) == nil)
    }

    @Test func savingsBaselineDoesNotDependOnBudget() {
        let results = [2500, 6000].map { budget in
            let (catalog, cover, months) = plan(budget)
            return Savings(catalog: catalog, cover: cover, months: months)
        }
        #expect(results[0].baseline == results[1].baseline)  // same baseline
        #expect(results[0].planned == results[1].planned)    // same total, just spread differently
        #expect(results[0].added == ["Prime Video"])         // reported, but...
        #expect(results[0].baseline == 2499 + 1599)          // ...baseline is current services only
    }

    @Test func primeMembersGetPrimeTitlesIncluded() {
        var services = Self.services
        services[3].includedWith = "amazon_prime"
        let (_, titles) = Planning.prepare(services: services, watchlist: Self.watchlist, memberships: ["amazon_prime": true])
        let (included, rest) = Planning.splitIncluded(titles)
        #expect(included.map(\.name) == ["Reacher"])
        #expect(!rest.map(\.name).contains("Reacher"))
    }

    @Test func nonMembersStillPayForPrimeVideo() {
        var services = Self.services
        services[3].includedWith = "amazon_prime"
        let (_, titles) = Planning.prepare(services: services, watchlist: Self.watchlist, memberships: ["amazon_prime": false])
        #expect(Planning.splitIncluded(titles).included.isEmpty)
    }
}

@Suite struct FreeTitlePlacement {
    static let catalog = Catalog([
        Service(name: "Netflix", price: 2499),
        Service(name: "Hulu", price: 1899),
        Service(name: "Peacock", price: 1299, current: true),
    ])

    func free(_ name: String, _ on: String...) -> Title {
        Title(id: name, name: name, services: on, free: ["Tubi TV"], library: [], included: [], months: 1)
    }

    @Test func freeTitleOnAPlannedServiceGoesInThatMonth() {
        let months = [Month(["Netflix": 2499]), Month(["Hulu": 1899])]
        let placed = Planning.placeFree([free("Tropic Thunder", "Hulu")], months: months, catalog: Self.catalog)
        #expect(placed.inPlan == ["Tropic Thunder": .init(month: 1, service: "Hulu")])
    }

    @Test func earliestPlannedMonthWins() {
        let months = [Month(["Netflix": 2499]), Month(["Hulu": 1899])]
        let placed = Planning.placeFree([free("X", "Hulu", "Netflix")], months: months, catalog: Self.catalog)
        #expect(placed.inPlan == ["X": .init(month: 0, service: "Netflix")])
    }

    @Test func freeTitleOnACurrentServiceThePlanDrops() {
        let placed = Planning.placeFree([free("Poker Face", "Peacock")], months: [Month(["Netflix": 2499])], catalog: Self.catalog)
        #expect(placed.onCurrent == ["Poker Face": "Peacock"])
    }

    @Test func freeOnlyWhenNoPaidOptionYouWillHave() {
        let placed = Planning.placeFree([free("Before Sunrise"), free("Y", "Hulu")], months: [Month(["Netflix": 2499])], catalog: Self.catalog)
        #expect(placed.freeOnly == ["Before Sunrise", "Y"])
    }
}

@Suite struct ManagementLinkLookup {
    let links = ManagementLinks.bundled

    func link(_ service: String, _ biller: String) -> String? {
        links.link(service: service, billedThrough: biller)
    }

    @Test func directBillingUsesTheServicePage() {
        #expect(link("Peacock", "Peacock") == "https://www.peacocktv.com/account/plans")
    }

    @Test func thirdPartyBillingUsesTheBillersPage() {
        #expect(link("Netflix", "Apple") == links.billers["Apple"]!.web)
    }

    @Test func billerAliases() {
        #expect(link("Peacock", "Comcast") == links.billers["Xfinity"]!.web)
        #expect(link("HBO Max", "Amazon Channels") == links.billers["Amazon"]!.web)
    }

    @Test func rokuExceptionSendsDisneyAndHuluToTheService() {
        #expect(link("Disney+", "Roku") == links.services["Disney+"]!.manage)
        #expect(link("Hulu", "Roku") == links.services["Hulu"]!.manage)
        #expect(link("Peacock", "Roku") == links.billers["Roku"]!.web)
    }

    @Test func iosLinksPreferTheBillersDeepLink() {
        #expect(links.iosLink(service: "Netflix", billedThrough: "Apple") == "itms-apps://apps.apple.com/account/subscriptions")
        #expect(links.iosLink(service: "Peacock", billedThrough: "Peacock") == link("Peacock", "Peacock"))
        #expect(links.iosLink(service: "Netflix", billedThrough: "Roku") == links.billers["Roku"]!.web)
    }

    @Test func keepActionsHaveNoLinks() {
        let hbo = Service(name: "HBO Max", price: 1699, current: true, renews: 28)
        let keep = Actions.plan(catalog: Catalog([hbo]), months: [Month(), Month(["HBO Max": 1699])], start: start, today: today)[0]
        #expect(keep.kind == .keep && keep.link == nil && keep.iosLink == nil)
    }

    @Test func unknownBillerFallsBackToTheServicePage() {
        #expect(link("Netflix", "Some Cable Co") == links.services["Netflix"]!.manage)
    }
}

@Suite struct Dates {
    @Test func dayIsClampedToMonthLength() {
        #expect(CalendarDate(2027, 1, 1).onDay(31, monthsLater: 1) == CalendarDate(2027, 2, 28))
        #expect(CalendarDate(2028, 1, 1).onDay(31, monthsLater: 1) == CalendarDate(2028, 2, 29))
    }

    @Test func monthsRollOverYears() {
        #expect(start.onDay(1, monthsLater: 3) == CalendarDate(2027, 1, 1))
        #expect(start.onDay(22, monthsLater: -1) == CalendarDate(2026, 9, 22))
    }
}

@Suite struct WholePlan {
    @Test func budgetBelowARequiredServiceFails() {
        #expect(throws: RotationPlan.Failure.budgetTooLow) {
            try RotationPlan.make(services: PlanningRules.services, watchlist: PlanningRules.watchlist,
                                  budget: 1000, start: start, today: today)
        }
    }

    @Test func onlyFreeAndUnavailableTitlesMakeAnEmptyPlan() throws {
        let plan = try RotationPlan.make(services: PlanningRules.services, watchlist: [
            WatchlistEntry(title: "Before Sunrise", services: [], free: ["Tubi TV"]),
            WatchlistEntry(title: "Boy Friends", services: ["Some Tiny Service"]),
        ], budget: 4000, start: start, today: today)
        #expect(plan.months.isEmpty)
        #expect(plan.freePlacement.freeOnly == ["Before Sunrise"])
        #expect(plan.unavailable.map(\.name) == ["Boy Friends"])
    }

    @Test func titlesInAMonthListPaidThenAlsoFree() throws {
        let plan = try RotationPlan.make(services: PlanningRules.services, watchlist: [
            WatchlistEntry(title: "Stranger Things", services: ["Netflix"]),
            WatchlistEntry(title: "Fighting Spirit", services: ["Netflix"], free: ["Plex"]),
        ], budget: 4000, start: start, today: today)
        #expect(plan.titles(in: 0, on: "Netflix").map(\.name) == ["Stranger Things", "Fighting Spirit"])
        #expect(plan.titles(in: 0, on: "Netflix").map(\.alsoFree) == [false, true])
    }
}

@Suite struct TitleIdentity {
    @Test func titlesWithTheSameNameArePlannedSeparately() throws {
        let plan = try RotationPlan.make(services: PlanningRules.services, watchlist: [
            WatchlistEntry(id: "wotw-2005", title: "War of the Worlds", services: ["Netflix"]),
            WatchlistEntry(id: "wotw-1953", title: "War of the Worlds", services: ["Hulu"]),
        ], budget: 6000, start: start, today: today)
        #expect(plan.cover.assignment == ["wotw-2005": "Netflix", "wotw-1953": "Hulu"])
        #expect(plan.title(id: "wotw-1953")?.services == ["Hulu"])
    }

    @Test func entriesSavedWithoutAnIdUseTheTitle() throws {
        let json = #"{"title": "Andor", "services": ["Disney Plus"]}"#
        let entry = try JSONDecoder().decode(WatchlistEntry.self, from: Data(json.utf8))
        #expect(entry.id == "Andor")
    }

    @Test func idsRoundTripThroughJSON() throws {
        let entry = WatchlistEntry(id: "abc", title: "Andor", services: ["Disney Plus"], months: 2)
        let decoded = try JSONDecoder().decode(WatchlistEntry.self, from: JSONEncoder().encode(entry))
        #expect(decoded == entry)
    }
}

@Suite struct NotOnAService {
    @Test func markedServiceIsIgnoredForThatTitle() throws {
        // The Bear is listed on Hulu and Disney+; Andor needs Disney+ anyway,
        // so normally The Bear rides along on Disney+.
        let watchlist = [
            WatchlistEntry(title: "Andor", services: ["Disney Plus"]),
            WatchlistEntry(title: "The Bear", services: ["Hulu", "Disney Plus"], notOn: ["Disney+"]),
        ]
        let plan = try RotationPlan.make(services: PlanningRules.services, watchlist: watchlist,
                                         budget: 6000, start: start, today: today)
        #expect(plan.cover.assignment["The Bear"] == "Hulu")
        #expect(plan.title(id: "The Bear")?.services == ["Hulu"])
        #expect(plan.title(id: "The Bear")?.notOn == ["Disney+"])
    }

    @Test func rawProviderNamesWorkToo() {
        let (_, titles) = Planning.prepare(services: PlanningRules.services, watchlist: [
            WatchlistEntry(title: "X", services: ["Netflix Standard with Ads", "Hulu"], notOn: ["Netflix"]),
        ])
        #expect(titles[0].services == ["Hulu"])
    }

    @Test func notOnAServiceItIsntListedOnIsIgnored() {
        let (_, titles) = Planning.prepare(services: PlanningRules.services, watchlist: [
            WatchlistEntry(title: "X", services: ["Hulu"], notOn: ["Netflix"]),
        ])
        #expect(titles[0].services == ["Hulu"])
        #expect(titles[0].notOn.isEmpty)
    }

    @Test func checkedOnAndNotOnRoundTripThroughJSON() throws {
        let entry = WatchlistEntry(id: "tmdb:tv:1", title: "X", services: ["Hulu"],
                                   checkedOn: CalendarDate(2026, 10, 2), notOn: ["Netflix"])
        let json = String(decoding: try JSONEncoder().encode(entry), as: UTF8.self)
        #expect(json.contains(#""checkedOn":"2026-10-02""#))
        #expect(try JSONDecoder().decode(WatchlistEntry.self, from: Data(json.utf8)) == entry)
    }

    @Test func olderEntriesWithoutTheNewFieldsStillLoad() throws {
        let entry = try JSONDecoder().decode(WatchlistEntry.self, from: Data(#"{"title": "X", "services": ["Hulu"]}"#.utf8))
        #expect(entry.checkedOn == nil)
        #expect(entry.notOn == nil)
    }
}

@Suite struct DayMaths {
    @Test func daysBetweenDates() {
        #expect(CalendarDate(2026, 10, 2).days(to: CalendarDate(2026, 10, 9)) == 7)
        #expect(CalendarDate(2026, 12, 28).days(to: CalendarDate(2027, 1, 4)) == 7)
        #expect(CalendarDate(2028, 2, 28).days(to: CalendarDate(2028, 3, 1)) == 2)  // leap year
        #expect(CalendarDate(2026, 10, 9).days(to: CalendarDate(2026, 10, 2)) == -7)
    }
}

@Suite struct ReminderRules {
    // Netflix renews on the 22nd and isn't needed; Hulu starts with the plan
    // (October, see `start`).
    static let services = [
        Service(name: "Netflix", price: 2499, current: true, renews: 22, billedThrough: "Apple"),
        Service(name: "Hulu", price: 1899),
    ]
    static let watchlist = [WatchlistEntry(title: "The Bear", services: ["Hulu"])]

    func plan(today: CalendarDate = today) throws -> RotationPlan {
        try RotationPlan.make(services: Self.services, watchlist: Self.watchlist,
                              budget: 4000, start: start, today: today)
    }

    @Test func cancelIsRemindedTwoDaysEarly() throws {
        let cancel = try #require(Reminders.make(plan: try plan(), today: today).first { $0.action.kind == .cancel })
        #expect(cancel.action.date == d(10, 22))
        #expect(cancel.day == d(10, 20))
    }

    @Test func startIsRemindedOnTheDayWithItsTitles() throws {
        let startHulu = try #require(Reminders.make(plan: try plan(), today: today).first { $0.action.kind == .start })
        #expect(startHulu.day == d(10, 1))
        #expect(startHulu.titles == ["The Bear"])
    }

    @Test func cancelDueTomorrowIsRemindedToday() throws {
        let oct21 = d(10, 21)
        let cancel = try #require(Reminders.make(plan: try plan(today: oct21), today: oct21).first { $0.action.kind == .cancel })
        #expect(cancel.day == oct21)
    }

    @Test func doneActionsAndKeepsAreSkipped() throws {
        let plan = try plan()
        let all = Reminders.make(plan: plan, today: today)
        #expect(!all.contains { $0.action.kind == .keep })
        let cancelID = try #require(all.first { $0.action.kind == .cancel }).id
        #expect(!Reminders.make(plan: plan, today: today, done: [cancelID]).contains { $0.id == cancelID })
    }

    @Test func pastActionsAreSkipped() throws {
        let later = d(12, 15)
        #expect(Reminders.make(plan: try plan(), today: later).allSatisfy { $0.action.date >= later })
    }

    @Test func soonestFirst() throws {
        let days = Reminders.make(plan: try plan(), today: today).map(\.day)
        #expect(days == days.sorted())
    }

    @Test func actionIdsAreStable() throws {
        let ids = try plan().actions.map(\.id)
        #expect(ids.contains("cancel-Netflix-2026-10-22"))
    }
}

@Suite struct AddingDays {
    @Test func addsAcrossMonthsYearsAndLeapDays() {
        #expect(CalendarDate(2026, 10, 22).adding(days: -2) == CalendarDate(2026, 10, 20))
        #expect(CalendarDate(2026, 11, 1).adding(days: -2) == CalendarDate(2026, 10, 30))
        #expect(CalendarDate(2027, 1, 1).adding(days: -1) == CalendarDate(2026, 12, 31))
        #expect(CalendarDate(2028, 2, 28).adding(days: 1) == CalendarDate(2028, 2, 29))
        #expect(CalendarDate(2026, 10, 2).adding(days: 0) == CalendarDate(2026, 10, 2))
    }
}
