import SwiftUI

@main
struct HealthWatchApp: App {
    @StateObject private var watchManager = WatchConnectivityManager()

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(watchManager)
        }
    }
}
