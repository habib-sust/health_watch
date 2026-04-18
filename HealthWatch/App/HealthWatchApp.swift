import SwiftUI
import UserNotifications

@main
struct HealthWatchApp: App {
    @StateObject private var watchManager = WatchConnectivityManager()

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(watchManager)
                .onAppear {
                    requestNotificationPermission()
                }
        }
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound, .badge]
        ) { _, _ in }
    }
}
