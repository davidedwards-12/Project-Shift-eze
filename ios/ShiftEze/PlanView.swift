import RotationEngine
import SwiftUI

/// The plan: savings, budget, what's active each month, and what to do when.
struct PlanView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        NavigationStack {
            List {
                if let notice = model.storageNotice {
                    Section {
                        Label(notice, systemImage: "exclamationmark.triangle")
                            .font(.subheadline)
                        Button("OK") { model.storageNotice = nil }
                    }
                }
                switch model.plan {
                case .success(let plan):
                    SavingsSection(savings: plan.savings)
                    BudgetSection(budget: $model.budget)
                    ForEach(plan.months.indices, id: \.self) { index in
                        MonthSection(plan: plan, index: index)
                    }
                    ActionsSection(actions: plan.actions)
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
            .navigationTitle("Your plan")
        }
    }
}

private struct SavingsSection: View {
    let savings: Savings

    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 6) {
                if savings.perMonth > 0 {
                    Text("Save \(savings.perMonth.centsAsMoney)/mo")
                        .font(.largeTitle.bold())
                        .foregroundStyle(.green)
                    Text("About \((savings.perMonth * 12).centsAsWholeDollars) a year")
                        .font(.headline)
                } else {
                    Text("No savings with this plan")
                        .font(.title2.bold())
                }
                Text("Paying now: \(savings.baseline.money)/mo · Plan average: \(savings.averagePerMonth.centsAsMoney)/mo")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
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

    var body: some View {
        Section {
            Stepper(value: $budget, in: 5_00...200_00, step: 5_00) {
                LabeledContent("Monthly budget", value: budget.money)
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
                Text(month.total.money)
            }
        }
    }
}

private struct ActionsSection: View {
    let actions: [Action]
    @Environment(\.openURL) private var openURL

    var body: some View {
        Section("Upcoming actions") {
            ForEach(actions, id: \.self) { action in
                if let link = action.iosLink ?? action.link, let url = URL(string: link) {
                    Button { open(url, fallback: action.link.flatMap(URL.init(string:))) } label: {
                        ActionRow(action: action, opensLink: true)
                    }
                    .buttonStyle(.plain)
                } else {
                    ActionRow(action: action, opensLink: false)
                }
            }
        }
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

    var body: some View {
        HStack {
            Image(systemName: action.kind.symbol)
                .foregroundStyle(action.kind.tint)
                .font(.title3)
            VStack(alignment: .leading) {
                Text(action.title).font(.headline)
                Text(action.detail).font(.subheadline).foregroundStyle(.secondary)
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

/// Titles the plan doesn't pay for: included, free, or not streaming.
private struct ElsewhereSection: View {
    let plan: RotationPlan
    let hasAmazonPrime: Bool

    var body: some View {
        if !plan.included.isEmpty {
            Section(hasAmazonPrime ? "Included with Amazon Prime" : "Included with a membership") {
                ForEach(plan.included, id: \.id) { TitleRow(name: $0.name, detail: $0.included.formatted()) }
            }
        }
        let placement = plan.freePlacement
        if !placement.onCurrent.isEmpty || !placement.freeOnly.isEmpty {
            Section("Free") {
                ForEach(placement.onCurrent.sorted(by: { $0.key < $1.key }), id: \.key) { id, service in
                    TitleRow(name: plan.title(id: id)?.name ?? id, detail: "On \(service), which you pay for now: watch before you cancel it")
                }
                ForEach(plan.free.filter { placement.freeOnly.contains($0.id) }, id: \.id) {
                    TitleRow(name: $0.name, detail: $0.free.formatted())
                }
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
        case .keep: .blue
        case .cancel: .red
        case .restart, .start: .green
        }
    }
}

#Preview {
    PlanView().environment(AppModel.sample())
}
