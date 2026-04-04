import SwiftUI

struct WatchHealthDataView: View {
    @StateObject private var viewModel = WatchHealthDataViewModel()
    @EnvironmentObject var appState: WatchAppState

    var body: some View {
        ScrollView {
            if viewModel.isLoading && viewModel.lastRefreshDate == nil {
                ProgressView("Loading...")
                    .padding(.top, 20)
            } else {
                VStack(spacing: 8) {
                    ForEach(viewModel.metrics) { metric in
                        WatchMetricCardView(metric: metric)
                    }

                    syncFooter
                }
                .padding(.horizontal, 4)
            }
        }
        .navigationTitle("Health")
        .task {
            await viewModel.loadLatestValues()
            viewModel.startAutoRefresh()
        }
        .onDisappear {
            viewModel.stopAutoRefresh()
        }
    }

    private var syncFooter: some View {
        VStack(spacing: 2) {
            if let name = appState.individualName {
                Text(name)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            if let lastSync = appState.lastSyncDate {
                Text("Synced \(lastSync, style: .relative) ago")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.top, 4)
        .padding(.bottom, 8)
    }
}
