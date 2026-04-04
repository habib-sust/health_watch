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

        // Pre-populate with mock data so dashboard is never empty
        self.individuals = MockIndividuals.all.map { individual in
            individual.toSummary(
                lastSyncDate: Date().addingTimeInterval(-Double.random(in: 60...3600)),
                latestHeartRate: Double.random(in: 62...88)
            )
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
        isLoading = individuals.isEmpty
        do {
            let fetched: [IndividualSummary] = try await apiClient.send(.getIndividuals())
            individuals = fetched
            error = nil
        } catch let err as APIError {
            // On failure, keep showing current data — don't blank the dashboard
            error = err
        } catch {
            // Network or other error — keep current data
        }
        isLoading = false
    }

    func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }
}
