import SwiftUI

@main
struct ShiftEzeApp: App {
    @State private var model = AppModel.launch()
    @Environment(\.scenePhase) private var scenePhase

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
            // Keep streaming availability fresh: on launch and whenever the
            // app comes back to the foreground.
            .task { await model.refreshAvailability() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { Task { await model.refreshAvailability() } }
            }
        }
    }
}
