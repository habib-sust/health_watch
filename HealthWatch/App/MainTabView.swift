import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var watchManager: WatchConnectivityManager

    var body: some View {
        TabView {
            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "heart.text.clipboard")
                }

            AlertsView()
                .tabItem {
                    Label("Alerts", systemImage: "bell")
                }

            ProvisioningView(watchManager: watchManager)
                .tabItem {
                    Label("Provision", systemImage: "qrcode.viewfinder")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
    }
}
