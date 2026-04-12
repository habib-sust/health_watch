import SwiftUI

@main
struct HealthWatchApp_Watch_AppApp: App {
    @WKApplicationDelegateAdaptor(ExtensionDelegate.self) var extensionDelegate
    @StateObject private var appState = WatchAppState.shared

    var body: some Scene {
        WindowGroup {
            Group {
                switch appState.mode {
                case .unprovisioned:
                    WatchUnprovisionedView()

                case .showingCode(let deviceCode):
                    WatchProvisionCodeView(deviceCode: deviceCode)

                case .provisioned:
                    WatchProvisionedTabView()

                case .error(let error):
                    WatchErrorView(error: error)
                }
            }
            .environmentObject(appState)
            .onAppear {
                setupConnectivity()
                appState.initialize()
            }
        }
    }

    private func setupConnectivity() {
        let handler = WatchConnectivityHandler.shared
        handler.activate()
    }
}
