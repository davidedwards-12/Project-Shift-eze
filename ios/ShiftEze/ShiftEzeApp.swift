import SwiftUI

@main
struct ShiftEzeApp: App {
    @State private var model = AppModel.launch()

    var body: some Scene {
        WindowGroup {
            TabView {
                Tab("Plan", systemImage: "calendar") { PlanView() }
                Tab("Services", systemImage: "tv") { ServicesView() }
                Tab("Watchlist", systemImage: "list.bullet") { WatchlistView() }
            }
            .environment(model)
        }
    }
}
