import SwiftUI
import UserNotifications

@main
struct ShiftEzeApp: App {
    @State private var model = AppModel.launch()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        UNUserNotificationCenter.current().delegate = NotificationHandler.shared
    }

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
            // Keep scheduled reminders in step with the plan.
            .onChange(of: model.reminders, initial: true) { _, reminders in
                Task { await ReminderScheduler.reschedule(reminders) }
            }
            // Ask for permission once there's something worth reminding
            // about, and not while onboarding is still on screen.
            .task(id: model.hasCompletedOnboarding && !model.reminders.isEmpty) {
                guard model.hasCompletedOnboarding, !model.reminders.isEmpty else { return }
                if await ReminderScheduler.requestPermissionIfNeeded() {
                    await ReminderScheduler.reschedule(model.reminders)
                }
            }
        }
    }
}
