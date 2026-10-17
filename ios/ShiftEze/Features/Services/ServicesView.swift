import RotationEngine
import SwiftUI

/// The user's subscriptions: what they pay for now, when it renews, who bills it.
struct ServicesView: View {
    @Environment(AppModel.self) private var model
    @State private var confirmReset = false

    var body: some View {
        @Bindable var model = model
        NavigationStack {
            List {
                Group {
                    Section {
                        Toggle("Amazon Prime", isOn: $model.hasAmazonPrime)
                    } header: {
                        Text("Memberships")
                    } footer: {
                        Text("Prime members get Prime Video at no extra cost, so it's never rotated.")
                    }
                    serviceSection("Paying for now") { $0.current && $0.includedVia == nil }
                    if model.services.contains(where: { $0.includedVia != nil }) {
                        serviceSection("Included with another plan") { $0.includedVia != nil }
                    }
                    serviceSection("Not subscribed") { !$0.current && $0.includedVia == nil }
                }
                .themedRows()
            }
            .themedList()
            .navigationTitle("Services")
            .toolbar {
                Menu {
                    Button("Start onboarding again", systemImage: "sparkles") {
                        model.restartOnboarding()
                    }
                    Button("Reset to sample data", systemImage: "arrow.counterclockwise", role: .destructive) {
                        confirmReset = true
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
            .confirmationDialog("Reset to sample data?", isPresented: $confirmReset, titleVisibility: .visible) {
                Button("Reset", role: .destructive) { model.resetToSample() }
            } message: {
                Text("Your subscriptions, watchlist and budget will be replaced with the sample data.")
            }
        }
    }

    private func serviceSection(_ title: String, _ belongs: (Service) -> Bool) -> some View {
        let indices = model.services.indices.filter { belongs(model.services[$0]) }
        return Section(title) {
            if indices.isEmpty {
                Text("None yet").foregroundStyle(.secondary)
            }
            ForEach(indices, id: \.self) { index in
                NavigationLink {
                    ServiceDetailView(index: index)
                } label: {
                    ServiceRow(service: model.services[index],
                               paidUntil: model.paidUntil(model.services[index].name))
                }
            }
        }
    }
}

private struct ServiceRow: View {
    let service: Service
    /// Set for a service the user cancelled that's still paid up.
    var paidUntil: CalendarDate?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(service.name).font(.headline)
                Spacer()
                if service.includedVia != nil {
                    Text("Included").foregroundStyle(.secondary)
                } else {
                    Text("\(service.price.money)/mo").monospacedDigit()
                }
            }
            if let via = service.includedViaLabel {
                Text("With \(via) · no extra cost")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else if service.current, let renews = service.renews {
                Text("Renews on the \(renews.ordinal) · \(billing)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else if let paidUntil {
                Text("Cancelled · paid up until \(paidUntil.short)")
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

    var body: some View {
        @Bindable var model = model
        let service = $model.services[index]
        let included = service.wrappedValue.includedVia != nil
        Form {
            Group {
                Section {
                    Toggle("I pay for this now", isOn: Binding(
                        get: { service.wrappedValue.current },
                        set: { pays in
                            if pays { model.setIncluded(nil, at: index) }
                            model.services[index].current = pays
                        }
                    ))
                    if !included {
                        PriceField(price: service.price)
                    }
                }
                Section {
                    Toggle("Included with another plan", isOn: Binding(
                        get: { included },
                        set: { model.setIncluded($0 ? "" : nil, at: index) }
                    ))
                    if included {
                        LabeledContent("Included with") {
                            TextField("Included with", text: Binding(
                                get: { service.wrappedValue.includedVia ?? "" },
                                set: { model.services[index].includedVia = $0 }
                            ), prompt: Text("Verizon"))
                            .multilineTextAlignment(.trailing)
                            .autocorrectionDisabled()
                        }
                    }
                } footer: {
                    Text("Get it at no extra cost through your phone, internet or another membership? We'll count its shows as included and never ask you to cancel it.")
                }
                if service.wrappedValue.current {
                    Section {
                        BillingFields(service: service)
                    } footer: {
                        Text(BillingFields.hint)
                    }
                }
            }
            .themedRows()
        }
        .themedList()
        .navigationTitle(service.wrappedValue.name)
    }
}

/// Monthly price, edited in dollars and stored in cents.
struct PriceField: View {
    @Binding var price: Cents

    var body: some View {
        LabeledContent("Price per month") {
            TextField("Price per month", value: dollars, format: .currency(code: "USD"))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
        }
    }

    private var dollars: Binding<Decimal> {
        Binding(
            get: { Decimal(price) / 100 },
            set: { price = NSDecimalNumber(decimal: $0 * 100).intValue }
        )
    }
}

/// Renewal day and who bills the subscription.
struct BillingFields: View {
    @Binding var service: Service

    static let hint = "Who bills you decides where you cancel. Check your bank or card statement if you're not sure."

    /// "Directly" plus every billing provider we have management links for.
    private var billers: [String] {
        ManagementLinks.bundled.billers.keys.sorted()
    }

    var body: some View {
        Picker("Renews on", selection: renewsDay) {
            ForEach(1...31, id: \.self) { Text("The \($0.ordinal)").tag($0) }
        }
        Picker("Billed through", selection: billedThrough) {
            Text("\(service.name) directly").tag(service.name)
            ForEach(billers, id: \.self) { Text($0).tag($0) }
        }
    }

    private var renewsDay: Binding<Int> {
        Binding(get: { service.renews ?? 1 }, set: { service.renews = $0 })
    }

    private var billedThrough: Binding<String> {
        Binding(
            get: { service.billedThrough ?? service.name },
            set: { service.billedThrough = $0 }
        )
    }
}

#Preview {
    ServicesView().environment(AppModel.sample())
}

extension Service {
    /// What it's included with, for display ("Verizon", or "another plan" if
    /// unnamed); nil if it isn't included with another plan.
    var includedViaLabel: String? {
        includedVia.map { $0.trimmingCharacters(in: .whitespaces).isEmpty ? "another plan" : $0 }
    }
}
