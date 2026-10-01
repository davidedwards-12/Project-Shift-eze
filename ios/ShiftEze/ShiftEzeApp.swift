import SwiftUI

@main
struct ShiftEzeApp: App {
    @State private var model = AppModel.launch()

    private var showOnboarding: Binding<Bool> {
        Binding(
            get: { !model.hasCompletedOnboarding },
            set: { if !$0 { model.hasCompletedOnboarding = true } }
        )
    }

    var body: some Scene {
        WindowGroup {
            TabView {
                Tab("Plan", systemImage: "calendar") { PlanView() }
                Tab("Services", systemImage: "tv") { ServicesView() }
                Tab("Watchlist", systemImage: "list.bullet") { WatchlistView() }
            }
            .environment(model)
            .fullScreenCover(isPresented: showOnboarding) {
                OnboardingView().environment(model)
            }
        }
    }
}
