import Foundation
import Combine

@MainActor
final class AlertsViewModel: ObservableObject {
    @Published var alerts: [AlertItem] = []
    @Published var isLoading = false
    @Published var error: APIError?

    private let apiClient: APIClient

    init() {
        let url = URL(string: DemoConfiguration.serverURL)!
        let tokenStore = StaticTokenStore(token: DemoConfiguration.apiToken)
        self.apiClient = APIClient(baseURL: url, tokenStore: tokenStore)

        // Pre-populate with mock alerts
        self.alerts = Self.mockAlerts()
    }

    func refresh() async {
        isLoading = alerts.isEmpty
        do {
            let fetched: [AlertItem] = try await apiClient.send(.getAlerts())
            alerts = fetched
            error = nil
        } catch let err as APIError {
            error = err
        } catch {}
        isLoading = false
    }

    var unacknowledgedCount: Int {
        alerts.filter { !$0.acknowledged }.count
    }

    var criticalAlerts: [AlertItem] {
        alerts.filter { $0.severity == .critical }
    }

    var warningAlerts: [AlertItem] {
        alerts.filter { $0.severity == .warning }
    }

    var infoAlerts: [AlertItem] {
        alerts.filter { $0.severity == .info }
    }

    // MARK: - Mock Data

    private static func mockAlerts() -> [AlertItem] {
        [
            AlertItem(
                id: "alert-001",
                individualId: "ind-003",
                individualName: "Carol Chen",
                metric: HealthKitTypes.heartRate,
                value: 112,
                threshold: 100,
                severity: .warning,
                message: "Heart rate elevated above threshold",
                timestamp: Date().addingTimeInterval(-1800),
                acknowledged: false
            ),
            AlertItem(
                id: "alert-002",
                individualId: "ind-003",
                individualName: "Carol Chen",
                metric: HealthKitTypes.heartRate,
                value: 142,
                threshold: 120,
                severity: .critical,
                message: "Heart rate critically elevated",
                timestamp: Date().addingTimeInterval(-900),
                acknowledged: false
            ),
            AlertItem(
                id: "alert-003",
                individualId: "ind-004",
                individualName: "David Park",
                metric: HealthKitTypes.heartRate,
                value: 0,
                threshold: 0,
                severity: .info,
                message: "No data received for over 2 hours",
                timestamp: Date().addingTimeInterval(-7200),
                acknowledged: true
            ),
        ]
    }
}
