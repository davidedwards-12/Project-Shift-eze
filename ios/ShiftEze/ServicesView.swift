import RotationEngine
import SwiftUI

/// The user's subscriptions: what they pay for now, when it renews, who bills it.
struct ServicesView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        NavigationStack {
            List {
                Section {
                    Toggle("Amazon Prime", isOn: $model.hasAmazonPrime)
                } header: {
                    Text("Memberships")
                } footer: {
                    Text("Prime members get Prime Video at no extra cost, so it's never rotated.")
                }
                serviceSection("Paying for now", current: true)
                serviceSection("Not subscribed", current: false)
            }
            .navigationTitle("Services")
        }
    }

    private func serviceSection(_ title: String, current: Bool) -> some View {
        Section(title) {
            ForEach(model.services.indices.filter { model.services[$0].current == current }, id: \.self) { index in
                NavigationLink {
                    ServiceDetailView(index: index)
                } label: {
                    ServiceRow(service: model.services[index])
                }
            }
        }
    }
}

private struct ServiceRow: View {
    let service: Service

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(service.name).font(.headline)
                Spacer()
                Text("\(service.price.money)/mo").monospacedDigit()
            }
            if service.current, let renews = service.renews {
                Text("Renews on the \(renews.ordinal) · \(billing)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var billing: String {
        let via = service.billedThrough ?? service.name
        return via == service.name ? "billed directly" : "via \(via)"
    }
}

/// Edit one subscription.
struct ServiceDetailView: View {
    @Environment(AppModel.self) private var model
    let index: Int

    /// "Directly" plus every billing provider we have management links for.
    private var billers: [String] {
        ManagementLinks.bundled.billers.keys.sorted()
    }

    var body: some View {
        @Bindable var model = model
        let service = $model.services[index]
        Form {
            Section {
                Toggle("I pay for this now", isOn: service.current)
                LabeledContent("Price per month") {
                    TextField("Price per month", value: dollars(service.price), format: .currency(code: "USD"))
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                }
            }
            if service.wrappedValue.current {
                Section {
                    Picker("Renews on", selection: renewsDay(service.renews)) {
                        ForEach(1...31, id: \.self) { Text("The \($0.ordinal)").tag($0) }
                    }
                    Picker("Billed through", selection: billedThrough(service)) {
                        Text("\(service.wrappedValue.name) directly").tag(service.wrappedValue.name)
                        ForEach(billers, id: \.self) { Text($0).tag($0) }
                    }
                } footer: {
                    Text("Who bills you decides where you cancel. Check your bank or card statement if you're not sure.")
                }
            }
        }
        .navigationTitle(service.wrappedValue.name)
    }

    private func dollars(_ cents: Binding<Cents>) -> Binding<Decimal> {
        Binding(
            get: { Decimal(cents.wrappedValue) / 100 },
            set: { cents.wrappedValue = NSDecimalNumber(decimal: ($0 * 100)).intValue }
        )
    }

    private func renewsDay(_ day: Binding<Int?>) -> Binding<Int> {
        Binding(get: { day.wrappedValue ?? 1 }, set: { day.wrappedValue = $0 })
    }

    private func billedThrough(_ service: Binding<Service>) -> Binding<String> {
        Binding(
            get: { service.wrappedValue.billedThrough ?? service.wrappedValue.name },
            set: { service.wrappedValue.billedThrough = $0 }
        )
    }
}

#Preview {
    ServicesView().environment(AppModel.sample())
}
