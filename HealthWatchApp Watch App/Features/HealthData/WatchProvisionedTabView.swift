import SwiftUI

struct WatchProvisionedTabView: View {
    @EnvironmentObject var appState: WatchAppState

    var body: some View {
        TabView {
            WatchHealthDataView()
            WatchSOSView()
            WatchStatusView()
        }
        .tabViewStyle(.verticalPage)
    }
}
