import Foundation
import Combine

@MainActor
final class DashboardViewModel: ObservableObject {
    @Published var individuals: [IndividualSummary] = []
    @Published var isLoading = false
    @Published var error: APIError?

    private let apiClient: APIClient
    private var pollingTask: Task<Void, Never>?

    init() {
        let url = URL(string: DemoConfiguration.serverURL)!
        let tokenStore = StaticTokenStore(token: DemoConfiguration.apiToken)
        self.apiClient = APIClient(baseURL: url, tokenStore: tokenStore)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleProvisioningChange),
            name: .watchDidDeprovision,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleProvisioningChange),
            name: .provisioningDidChange,
            object: nil
        )
    }

    @objc private func handleProvisioningChange() {
        Task { @MainActor in
            await refresh()
        }
    }

    func startPolling() {
        pollingTask = Task {
            while !Task.isCancelled {
                await refresh()
                try? await Task.sleep(for: .seconds(AppConstants.dashboardPollingInterval))
            }
        }
    }

    func refresh() async {
        let provisionedId = UserDefaults.standard.string(forKey: "provisionedIndividualId")
        let provisionedName = UserDefaults.standard.string(forKey: "provisionedIndividualName")

        guard let individualId = provisionedId, let name = provisionedName else {
            individuals = []
            isLoading = false
            return
        }

        isLoading = individuals.isEmpty

        // Fetch latest health samples for the provisioned individual
        let now = Date()
        let oneDayAgo = now.addingTimeInterval(-24 * 3600)

        var lastSync: Date?
        var latestHR: Double?

        do {
            let samples: [HealthSample] = try await apiClient.send(
                .getHealth(individualId: individualId, from: oneDayAgo, to: now)
            )

            // Latest sample date = last sync
            lastSync = samples.map(\.endDate).max()

            // Latest heart rate
            latestHR = samples
                .filter { $0.typeIdentifier == HealthKitTypes.heartRate }
                .max(by: { $0.startDate < $1.startDate })?
                .value

            error = nil
        } catch let err as APIError {
            error = err
        } catch {
            // Network error — keep current data if we have it
            if !individuals.isEmpty { return }
        }

        individuals = [
            IndividualSummary(
                id: individualId,
                name: name,
                status: lastSync != nil ? .normal : .offline,
                lastSyncDate: lastSync,
                latestHeartRate: latestHR
            )
        ]

        isLoading = false
    }

    func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }
}
