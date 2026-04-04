import SwiftUI

struct WatchProvisionedTabView: View {
    @EnvironmentObject var appState: WatchAppState

    var body: some View {
        if #available(watchOS 10.0, *) {
            TabView {
                WatchHealthDataView()
                WatchStatusView()
            }
            .tabViewStyle(.verticalPage)
        } else {
            TabView {
                WatchHealthDataView()
                WatchStatusView()
            }
            .tabViewStyle(.page)
        }
    }
}
