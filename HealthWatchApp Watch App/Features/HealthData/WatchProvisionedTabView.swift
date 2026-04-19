import SwiftUI

struct WatchProvisionedTabView: View {
    @EnvironmentObject var appState: WatchAppState

    var body: some View {
        TabView {
            DailyActivityView()
            WatchAssistanceView()
            WatchStatusView()
        }
        .tabViewStyle(.verticalPage)
    }
}
