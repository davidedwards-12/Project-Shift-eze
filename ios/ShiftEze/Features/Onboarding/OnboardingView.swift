import RotationEngine
import SwiftUI

/// First-launch setup: welcome → subscriptions → watchlist → budget, then the
/// plan. Every step can be skipped, and everything is editable later in the
/// Services and Watchlist tabs.
struct OnboardingView: View {
    @Environment(AppModel.self) private var model
    @State private var step = Step.welcome

    enum Step: Int, CaseIterable {
        case welcome, subscriptions, watchlist, budget

        var title: String {
            switch self {
            case .welcome: ""
            case .subscriptions: "Your subscriptions"
            case .watchlist: "What to watch"
            case .budget: "Your budget"
            }
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                switch step {
                case .welcome: WelcomeStep(start: { go(to: .subscriptions) }, skip: finish)
                case .subscriptions: SubscriptionsStep()
                case .watchlist: WatchlistStep()
                case .budget: BudgetStep()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if step != .welcome {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Back", systemImage: "chevron.left") { go(to: Step(rawValue: step.rawValue - 1)!) }
                    }
                    ToolbarItem(placement: .principal) {
                        VStack(spacing: 0) {
                            Text(step.title)
                                .font(.headline)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                            Text("Step \(step.rawValue) of \(Step.allCases.count - 1)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Skip") { finish() }
                            .accessibilityLabel("Skip setup")
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if step != .welcome {
                    Button(action: next) {
                        Text(nextLabel).frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .padding()
                    // Solid backing so list text doesn't show through behind the button.
                    .background(.bar)
                }
            }
            // Keep the button at the bottom, behind the keyboard, instead of
            // riding up over the search results. Scrolling dismisses the keyboard.
            .ignoresSafeArea(.keyboard, edges: .bottom)
        }
        .interactiveDismissDisabled()
    }

    private var nextLabel: String {
        switch step {
        case .watchlist where model.watchlist.isEmpty: "Skip for now"
        case .budget: "See my plan"
        default: "Next"
        }
    }

    private func next() {
        if let following = Step(rawValue: step.rawValue + 1) {
            go(to: following)
        } else {
            finish()
        }
    }

    private func go(to step: Step) {
        withAnimation { self.step = step }
    }

    private func finish() {
        model.hasCompletedOnboarding = true
    }
}

private struct WelcomeStep: View {
    let start: () -> Void
    let skip: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 64, weight: .semibold))
                .foregroundStyle(.tint)
                .accessibilityHidden(true)
            Text("Pay only for the streaming you watch")
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)
            Text("Tell us what you want to watch and your monthly budget. We'll work out which services to keep each month, and when to cancel and restart them.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Spacer()
            Button(action: start) {
                Text("Get started").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            Button("Skip for now", action: skip)
        }
        .padding(24)
    }
}

/// Which services the user pays for now, with price, renewal day and biller.
private struct SubscriptionsStep: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        List {
            Section {
                Toggle("Amazon Prime", isOn: $model.hasAmazonPrime)
            } header: {
                Text("Memberships")
            } footer: {
                Text("Prime includes Prime Video at no extra cost.")
            }
            Section {
                ForEach(model.services.indices, id: \.self) { index in
                    ServiceSetupRow(
                        service: $model.services[index],
                        includedWithPrime: model.hasAmazonPrime && model.services[index].includedWith == "amazon_prime"
                    )
                }
            } header: {
                Text("Which do you pay for now?")
            } footer: {
                Text(BillingFields.hint)
            }
        }
    }
}

private struct ServiceSetupRow: View {
    @Binding var service: Service
    let includedWithPrime: Bool

    var body: some View {
        if includedWithPrime {
            LabeledContent(service.name, value: "Included with Prime")
        } else {
            Toggle(isOn: $service.current) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(service.name)
                    Text("\(service.price.money)/mo").font(.caption).foregroundStyle(.secondary)
                }
            }
            if service.current {
                PriceField(price: $service.price)
                BillingFields(service: $service)
            }
        }
    }
}

private struct WatchlistStep: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(spacing: 0) {
            Text(prompt)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.vertical, 8)
            TitleSearchView(autoFocus: false)
        }
    }

    private var prompt: String {
        switch model.watchlist.count {
        case 0: "Add a few movies or shows. You'll need at least one to see a plan."
        case 1: "1 added. Add more, or tap Next."
        case let n: "\(n) added. Add more, or tap Next."
        }
    }
}

private struct BudgetStep: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        List {
            Section {
                VStack(spacing: 8) {
                    Text(model.budget.money)
                        .font(.system(size: 48, weight: .bold))
                        .monospacedDigit()
                    Stepper("Monthly budget", value: $model.budget, in: 5_00...200_00, step: 5_00)
                        .labelsHidden()
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            } footer: {
                Text("The most you want to spend on streaming in any month.")
            }
            Section {
                LabeledContent("You pay now", value: "\(payingNow.money)/mo")
                preview
            }
        }
    }

    private var payingNow: Cents {
        model.services.filter(\.current).reduce(0) { $0 + $1.price }
    }

    @ViewBuilder private var preview: some View {
        switch model.plan {
        case .success(let plan) where plan.months.isEmpty:
            Text(model.watchlist.isEmpty
                 ? "Add titles to your watchlist to see your plan."
                 : "Everything on your watchlist is free or included.")
                .foregroundStyle(.secondary)
        case .success(let plan):
            let months = plan.months.count
            Text("Your watchlist fits in \(months) month\(months == 1 ? "" : "s") at about \(plan.savings.averagePerMonth.centsAsMoney)/mo.")
        case .failure:
            Label("Something on your watchlist costs more than this budget.", systemImage: "exclamationmark.triangle")
                .foregroundStyle(.orange)
        }
    }
}

#Preview {
    OnboardingView().environment(AppModel(state: .newUser, store: nil))
}
