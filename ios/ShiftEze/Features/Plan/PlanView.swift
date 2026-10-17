import RotationEngine
import SwiftUI

/// The plan: savings, budget, what's active each month, and what to do when.
struct PlanView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        NavigationStack {
            List {
                Group {
                    if let notice = model.storageNotice {
                        Section {
                            Label(notice, systemImage: "exclamationmark.triangle")
                                .font(.subheadline)
                            Button("OK") { model.storageNotice = nil }
                        }
                    }
                    if let actual = model.actualSavings, let baseline = model.baseline {
                        ActualSavingsSection(summary: actual, baseline: baseline)
                    }
                    switch model.plan {
                    case .success(let plan) where plan.months.isEmpty:
                        // No paid months: savings would just be everything you pay
                        // now, so don't show a number.
                        EmptyPlanSection(watchlistIsEmpty: model.watchlist.isEmpty,
                                         allWatched: model.watchlist.allSatisfy { $0.watchedOn != nil })
                        BudgetSection(budget: $model.budget)
                        if !model.watchlist.isEmpty {
                            // Everything is free or included: cancelling is real advice.
                            ActionsSection(plan: plan)
                        }
                        DoneSection()
                        ElsewhereSection(plan: plan, hasAmazonPrime: model.hasAmazonPrime)
                    case .success(let plan):
                        SavingsSection(savings: plan.savings)
                        BudgetSection(budget: $model.budget, startsOn: model.start)
                        ForEach(plan.months.indices, id: \.self) { index in
                            MonthSection(plan: plan, index: index)
                        }
                        ActionsSection(plan: plan)
                        DoneSection()
                        ElsewhereSection(plan: plan, hasAmazonPrime: model.hasAmazonPrime)
                    case .failure:
                        BudgetSection(budget: $model.budget)
                        Section {
                            ContentUnavailableView(
                                "Budget too low",
                                systemImage: "exclamationmark.triangle",
                                description: Text("Something on your watchlist is only on a service that costs more than your monthly budget.")
                            )
                        }
                    }
                }
                .themedRows()
            }
            .themedList()
            .navigationTitle("Your plan")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        AboutView()
                    } label: {
                        Label("About", systemImage: "info.circle")
                    }
                }
            }
        }
    }
}

private struct EmptyPlanSection: View {
    let watchlistIsEmpty: Bool
    /// Everything on the watchlist is marked watched.
    let allWatched: Bool

    var body: some View {
        Section {
            if watchlistIsEmpty {
                ContentUnavailableView(
                    "No plan yet",
                    systemImage: "list.bullet",
                    description: Text("Add movies and shows on the Watchlist tab and we'll plan which services you need.")
                )
            } else if allWatched {
                ContentUnavailableView(
                    "You've watched everything",
                    systemImage: "checkmark.circle",
                    description: Text("Nothing left to pay for. Add more on the Watchlist tab when you're ready.")
                )
            } else {
                ContentUnavailableView(
                    "Nothing to pay for",
                    systemImage: "checkmark.seal",
                    description: Text("Everything on your watchlist is free with ads or included with something you already have. To watch something ad-free, open it on the Watchlist tab.")
                )
            }
        }
    }
}

/// Money actually saved so far: real charges vs. what the user paid before.
private struct ActualSavingsSection: View {
    let summary: ActualSavings.Summary
    let baseline: Baseline

    var body: some View {
        Section {
            let year = summary.thisYear.saved
            // The gradient is for good news only.
            let hero = year >= 0
            VStack(alignment: .leading, spacing: 4) {
                Text(hero ? "You've saved" : "You've spent")
                    .font(.headline)
                Text(hero ? year.money : (-year).money)
                    .font(.system(size: 52, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Text(hero ? "this year" : "more than before this year")
                    .font(.headline)
                Text("This month \(summary.thisMonth.saved.money) · All time \(summary.allTime.saved.money)")
                    .font(.subheadline.weight(.medium))
                    .opacity(0.75)
                    .padding(.top, 8)
            }
            .foregroundStyle(hero ? Theme.onGradient : Theme.text)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 12)
            .accessibilityElement(children: .combine)
            .listRowBackground(Rectangle().fill(hero ? AnyShapeStyle(Theme.gradient) : AnyShapeStyle(Theme.surface)))
            NavigationLink {
                BaselineView()
            } label: {
                LabeledContent("What you paid before", value: "\(baseline.monthly.money)/mo")
            }
        } header: {
            Text("Your savings")
        } footer: {
            Text("Real charges since \(summary.since.short), compared with what your old subscriptions would have charged.")
        }
    }
}

/// Edit which subscriptions count as "what you paid before".
private struct BaselineView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        List {
            Group {
                Section {
                    ForEach(model.services, id: \.name) { service in
                        Toggle(isOn: Binding(
                            get: { model.baseline?.contains(service.name) ?? false },
                            set: { model.setInBaseline(service, $0) }
                        )) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(service.name)
                                Text("\(service.price.money)/mo").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                } footer: {
                    Text("The subscriptions you were paying for before you started rotating. Savings compare your real charges with what these would have cost, since \(model.baseline?.since.short ?? "today").")
                }
            }
            .themedRows()
        }
        .themedList()
        .navigationTitle("What you paid before")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct SavingsSection: View {
    let savings: Savings

    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 6) {
                if savings.perMonth > 0 {
                    Text("On track to save \(savings.perMonth.centsAsMoney)/mo")
                        .font(.title2.bold())
                        .foregroundStyle(Theme.highlight)
                    Text("About \((savings.perMonth * 12).centsAsWholeDollars) a year")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                } else {
                    Text("No savings with this plan")
                        .font(.title2.bold())
                }
                Text("Paying now: \(savings.baseline.money)/mo · Plan average: \(savings.averagePerMonth.centsAsMoney)/mo")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        } header: {
            Text("This plan")
        } footer: {
            if savings.added.isEmpty {
                Text("Projected from this plan.")
            } else {
                Text("Projected from this plan. It also uses \(savings.added.formatted()), which you don't pay for now.")
            }
        }
    }
}

private struct BudgetSection: View {
    @Binding var budget: Cents
    /// When the first planned month begins, if there is one.
    var startsOn: CalendarDate? = nil

    var body: some View {
        Section {
            Stepper(value: $budget, in: 5_00...200_00, step: 5_00) {
                LabeledContent("Monthly budget", value: budget.money)
            }
        } footer: {
            if let startsOn {
                Text("Your plan starts \(startsOn.short). Anything to do before then is under Upcoming actions.")
            }
        }
    }
}

private struct MonthSection: View {
    let plan: RotationPlan
    let index: Int

    var body: some View {
        let month = plan.months[index]
        Section {
            ForEach(month.services, id: \.self) { service in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(service).font(.headline)
                        Spacer()
                        Text(month.prices[service]!.money).monospacedDigit()
                    }
                    ForEach(plan.titles(in: index, on: service), id: \.id) { title in
                        HStack(spacing: 4) {
                            Text(title.name)
                            if title.alsoFree {
                                Text("also free").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .font(.subheadline)
                    }
                }
                .padding(.vertical, 2)
            }
        } header: {
            HStack {
                Text(plan.date(ofMonth: index).monthAndYear)
                Spacer()
                Text(month.total.money).foregroundStyle(Theme.highlight)
            }
        }
    }
}

private struct ActionsSection: View {
    let plan: RotationPlan
    @Environment(AppModel.self) private var model
    @Environment(\.openURL) private var openURL

    var body: some View {
        Section {
            ForEach(plan.actions, id: \.self) { action in
                let note = headsUp(for: action)
                Group {
                    if let link = action.iosLink ?? action.link, let url = URL(string: link) {
                        Button { open(url, fallback: action.link.flatMap(URL.init(string:))) } label: {
                            ActionRow(action: action, opensLink: true, note: note)
                        }
                        .buttonStyle(.plain)
                    } else {
                        ActionRow(action: action, opensLink: false, note: note)
                    }
                }
                .swipeActions {
                    if action.kind != .keep {
                        Button("Done", systemImage: "checkmark") {
                            withAnimation { model.markDone(action) }
                        }
                        .tint(Theme.Palette.violet)
                    }
                }
            }
        } header: {
            Text("Upcoming actions")
        } footer: {
            Text("We'll remind you before each one. Once you've done it, swipe left and tap Done to update your subscriptions.")
        }
    }

    /// Before subscribing: a nudge to check the titles really are there,
    /// since TMDB is sometimes wrong or out of date.
    private func headsUp(for action: Action) -> String? {
        guard action.kind == .start || action.kind == .restart else { return nil }
        let titles = plan.paid.filter { plan.cover.assignment[$0.id] == action.service }
        guard let first = titles.first else { return nil }
        let names = switch titles.count {
        case 1: first.name
        case 2: "\(first.name) and \(titles[1].name)"
        default: "\(first.name) and \(titles.count - 1) more"
        }
        let dates = titles.compactMap(\.checkedOn)
        let checked = dates.count == titles.count ? dates.min().map { " · checked \($0.short)" } ?? "" : ""
        return "Check \(names) \(titles.count == 1 ? "is" : "are") on \(action.service) first\(checked)"
    }

    /// Open the app deep link; if nothing handles it (e.g. no App Store in
    /// the simulator), open the web page instead.
    private func open(_ url: URL, fallback: URL?) {
        openURL(url) { accepted in
            if !accepted, let fallback, fallback != url { openURL(fallback) }
        }
    }
}

private struct ActionRow: View {
    let action: Action
    let opensLink: Bool
    var note: String?

    var body: some View {
        HStack {
            Image(systemName: action.kind.symbol)
                .foregroundStyle(action.kind.tint)
                .font(.title3)
            VStack(alignment: .leading) {
                Text(action.title).font(.headline)
                Text(action.detail).font(.subheadline).foregroundStyle(.secondary)
                if let note {
                    Label(note, systemImage: "info.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 2)
                }
            }
            Spacer()
            Text(action.date.short).monospacedDigit().foregroundStyle(.secondary)
            Image(systemName: "arrow.up.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tint)
                .opacity(opensLink ? 1 : 0)
                .accessibilityHidden(true)
        }
        .contentShape(.rect)
        .accessibilityHint(opensLink ? "Opens where to \(action.kind.rawValue.lowercased()) it" : "")
    }
}

/// Actions marked done in the last 30 days, with Undo.
private struct DoneSection: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let recent = model.recentChanges
        if !recent.isEmpty {
            Section {
                ForEach(recent) { change in
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.secondary)
                            .font(.title3)
                        VStack(alignment: .leading) {
                            Text(change.title).font(.headline)
                            Text(change.detail).font(.subheadline).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(change.doneOn.short).monospacedDigit().foregroundStyle(.secondary)
                    }
                    .swipeActions {
                        Button("Undo", systemImage: "arrow.uturn.backward") {
                            withAnimation { model.undo(change) }
                        }
                        .tint(.gray)
                    }
                }
            } header: {
                Text("Done recently")
            } footer: {
                Text("Swipe left to undo.")
            }
        }
    }
}

extension SubscriptionChange {
    var title: String {
        switch kind {
        case .cancelled: "Cancelled \(service)"
        case .started: "Started \(service)"
        }
    }

    var detail: String {
        switch kind {
        case .cancelled: "Paid up until \(effectiveOn.short)"
        case .started: "Renews on the \(effectiveOn.day.ordinal)"
        }
    }
}

/// Titles the plan doesn't pay for: included, free, or not streaming.
private struct ElsewhereSection: View {
    let plan: RotationPlan
    let hasAmazonPrime: Bool

    var body: some View {
        if !plan.included.isEmpty {
            Section("Already included") {
                ForEach(plan.included, id: \.id) { title in
                    TitleRow(name: title.name, detail: title.included.map(includedLabel).formatted())
                }
            }
        }
        let placement = plan.freePlacement
        if !placement.onCurrent.isEmpty || !placement.freeOnly.isEmpty {
            Section {
                ForEach(placement.onCurrent.sorted(by: { $0.key < $1.key }), id: \.key) { id, service in
                    TitleRow(name: plan.title(id: id)?.name ?? id, detail: "On \(service), which you pay for now: watch before you cancel it")
                }
                ForEach(plan.free.filter { placement.freeOnly.contains($0.id) }, id: \.id) {
                    TitleRow(name: $0.name, detail: "Free with ads on \($0.free.formatted())")
                }
            } header: {
                Text("Free")
            } footer: {
                Text("We don't pay for a service for these. To watch one ad-free, open it on the Watchlist tab.")
            }
        }
        if !plan.library.isEmpty {
            Section {
                ForEach(plan.library, id: \.id) { TitleRow(name: $0.name, detail: $0.library.formatted()) }
            } header: {
                Text("Also free with a library card")
            }
        }
        if !plan.unavailable.isEmpty {
            Section("Not on a tracked service") {
                ForEach(plan.unavailable, id: \.id) { TitleRow(name: $0.name, detail: "Not streaming anywhere we track right now") }
            }
        }
    }
}

extension ElsewhereSection {
    /// "Hulu with Verizon", "Prime Video with Amazon Prime".
    func includedLabel(_ name: String) -> String {
        let service = plan.catalog[name]
        if let via = service.includedViaLabel { return "\(name) with \(via)" }
        if service.includedWith == "amazon_prime", hasAmazonPrime { return "\(name) with Amazon Prime" }
        return name
    }
}

private struct TitleRow: View {
    let name: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading) {
            Text(name)
            Text(detail).font(.subheadline).foregroundStyle(.secondary)
        }
    }
}

extension Action {
    var detail: String {
        switch kind {
        case .keep: "Renews · billed through \(billedThrough)"
        case .cancel: "Before it renews · through \(billedThrough)"
        case .restart, .start: "Through \(billedThrough)"
        }
    }
}

extension Action.Kind {
    var symbol: String {
        switch self {
        case .keep: "checkmark.circle.fill"
        case .cancel: "xmark.circle.fill"
        case .restart, .start: "play.circle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .keep: Theme.Palette.blue
        case .cancel: Theme.accentSecondary
        case .restart, .start: Theme.highlight
        }
    }
}

#Preview {
    PlanView().environment(AppModel.sample())
}
