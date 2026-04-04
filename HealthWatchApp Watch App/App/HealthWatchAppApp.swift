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
                    AwaitingSetupView()

                case .provisioning(let message):
                    WatchCodeEntryView(individualName: message.individualName)

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

        handler.onProvisioningInitiated = { message in
            Task { @MainActor in
                appState.beginProvisioning(with: message)
            }
        }

        handler.onConfigReceived = { message in
            Task { @MainActor in
                appState.completeProvisioning(individualName: message.individualName)
            }
        }

        handler.onCodeFailed = {
            // Watch stays on code entry view — user can retry
        }
    }
}
