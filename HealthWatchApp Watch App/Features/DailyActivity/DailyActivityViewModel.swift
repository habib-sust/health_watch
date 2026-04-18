import SwiftUI
import Combine
import HealthKit
import os

@MainActor
final class DailyActivityViewModel: ObservableObject {
    // MARK: - Published State

    @Published var heartRate = HeartRateData()
    @Published var steps = StepsData()
    @Published var sleep: SleepSession?
    @Published var heartRateHistory: [ActivityDataPoint] = []
    @Published var hourlySteps: [HourlyStepBucket] = []

    @Published var isLoading = false
    @Published var authStatus: HealthAuthStatus = .notDetermined
    @Published var lastRefreshDate: Date?

    // MARK: - Private

    private let service = HealthKitService.shared
    private let store = HKHealthStore()
    private var observerQueries: [HKQuery] = []
    private var refreshTask: Task<Void, Never>?

    // MARK: - Lifecycle

    func onAppear() async {
        authStatus = await service.checkAuthorizationStatus()
        guard authStatus == .authorized else { return }
        await refresh()
        startObservers()
        startAutoRefresh()
    }

    func onDisappear() {
        stopObservers()
        stopAutoRefresh()
    }

    deinit {
        let queries = observerQueries
        let store = self.store
        for query in queries {
            store.stop(query)
        }
    }

    // MARK: - Authorization

    func requestAccess() async {
        do {
            try await service.requestAuthorization()
            authStatus = await service.checkAuthorizationStatus()
            if authStatus == .authorized {
                await refresh()
                startObservers()
                startAutoRefresh()
            }
        } catch {
            Logger.healthKit.error("[DailyActivityVM] Authorization error: \(error.localizedDescription)")
        }
    }

    // MARK: - Refresh

    func refresh() async {
        let isFirstLoad = lastRefreshDate == nil
        if isFirstLoad { isLoading = true }

        let snapshot = await service.fetchDailySnapshot()

        heartRate = snapshot.heartRate
        steps = snapshot.steps
        sleep = snapshot.sleep
        heartRateHistory = snapshot.heartRateHistory
        hourlySteps = snapshot.hourlySteps
        lastRefreshDate = Date()

        if isFirstLoad { isLoading = false }

        Logger.healthKit.info("[DailyActivityVM] Refresh complete — HR: \(self.heartRate.formattedCurrent), steps: \(self.steps.formattedTotal), sleep: \(self.sleep?.formattedTotal ?? "none")")
    }

    // MARK: - Observer Queries

    private func startObservers() {
        stopObservers()

        let handler: @Sendable () -> Void = { [weak self] in
            Task { @MainActor in
                await self?.refresh()
            }
        }

        if let hrQuery = service.makeObserverQuery(for: .heartRate, updateHandler: handler) {
            store.execute(hrQuery)
            observerQueries.append(hrQuery)
        }

        if let stepsQuery = service.makeObserverQuery(for: .stepCount, updateHandler: handler) {
            store.execute(stepsQuery)
            observerQueries.append(stepsQuery)
        }

        let sleepQuery = service.makeSleepObserverQuery(updateHandler: handler)
        store.execute(sleepQuery)
        observerQueries.append(sleepQuery)

        Logger.healthKit.info("[DailyActivityVM] Started \(self.observerQueries.count) observer queries")
    }

    private func stopObservers() {
        for query in observerQueries {
            store.stop(query)
        }
        observerQueries.removeAll()
    }

    // MARK: - Auto Refresh

    private func startAutoRefresh() {
        stopAutoRefresh()
        refreshTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 60_000_000_000)
                guard !Task.isCancelled else { break }
                await refresh()
            }
        }
    }

    private func stopAutoRefresh() {
        refreshTask?.cancel()
        refreshTask = nil
    }
}
