import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var watchManager: WatchConnectivityManager

    var body: some View {
        NavigationStack {
            List {
                // Staff info
                Section("Staff") {
                    LabeledContent("Name", value: DemoConfiguration.staffName)
                    LabeledContent("Staff ID", value: DemoConfiguration.staffId)
                }

                // Watch status
                Section("Apple Watch") {
                    HStack {
                        Text("Connection")
                        Spacer()
                        HStack(spacing: 6) {
                            Circle()
                                .fill(watchManager.isWatchReachable ? .green : .gray)
                                .frame(width: 8, height: 8)
                            Text(watchManager.isWatchReachable ? "Connected" : "Not Connected")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // Server
                Section("Server") {
                    LabeledContent("URL", value: DemoConfiguration.serverURL)
                    LabeledContent("Mode", value: "Demo")
                }

                // App info
                Section("About") {
                    LabeledContent("Version", value: appVersion)
                    LabeledContent("Build", value: buildNumber)
                }
            }
            .navigationTitle("Settings")
        }
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
}

#Preview {
    SettingsView()
        .environmentObject(WatchConnectivityManager())
}
