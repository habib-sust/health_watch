import Foundation
import Combine

enum TimeRange: String, CaseIterable, Identifiable {
    case last24Hours = "24 Hours"
    case last7Days = "7 Days"
    case last30Days = "30 Days"

    var id: String { rawValue }

    var hours: Int {
        switch self {
        case .last24Hours: return 24
        case .last7Days: return 24 * 7
        case .last30Days: return 24 * 30
        }
    }

    var dateRange: (from: Date, to: Date) {
        let to = Date()
        let from = to.addingTimeInterval(-Double(hours) * 3600)
        return (from, to)
    }
}

@MainActor
final class IndividualDetailViewModel: ObservableObject {
    @Published var selectedTimeRange: TimeRange = .last24Hours
    @Published var heartRateSamples: [HealthSample] = []
    @Published var oxygenSamples: [HealthSample] = []
    @Published var stepSamples: [HealthSample] = []
    @Published var respiratoryRateSamples: [HealthSample] = []
    @Published var isLoading = false

    let individual: IndividualSummary
    private let apiClient: APIClient

    init(individual: IndividualSummary) {
        self.individual = individual
        let url = URL(string: DemoConfiguration.serverURL)!
        let tokenStore = StaticTokenStore(token: DemoConfiguration.apiToken)
        self.apiClient = APIClient(baseURL: url, tokenStore: tokenStore)
    }

    func loadData() async {
        isLoading = true
        let hours = selectedTimeRange.hours

        // Try to fetch from server; fall back to mock data
        do {
            let range = selectedTimeRange.dateRange
            let samples: [HealthSample] = try await apiClient.send(
                .getHealth(individualId: individual.id, from: range.from, to: range.to)
            )
            categorizeSamples(samples)
        } catch {
            // Fall back to mock data
            loadMockData(hours: hours)
        }

        isLoading = false
    }

    private func categorizeSamples(_ samples: [HealthSample]) {
        heartRateSamples = samples.filter { $0.typeIdentifier == HealthKitTypes.heartRate }
        oxygenSamples = samples.filter { $0.typeIdentifier == HealthKitTypes.oxygenSaturation }
        stepSamples = samples.filter { $0.typeIdentifier == HealthKitTypes.stepCount }
        respiratoryRateSamples = samples.filter { $0.typeIdentifier == HealthKitTypes.respiratoryRate }
    }

    private func loadMockData(hours: Int) {
        heartRateSamples = MockHealthData.heartRateSamples(for: individual.id, hours: hours)
        oxygenSamples = MockHealthData.oxygenSaturationSamples(for: individual.id, hours: hours)
        stepSamples = MockHealthData.stepCountSamples(for: individual.id, hours: hours)
        respiratoryRateSamples = MockHealthData.respiratoryRateSamples(for: individual.id, hours: hours)
    }
}
