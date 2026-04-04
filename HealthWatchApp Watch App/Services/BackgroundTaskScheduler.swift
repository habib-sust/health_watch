import WatchKit

final class BackgroundTaskScheduler {
    static let shared = BackgroundTaskScheduler()

    private let preferredInterval = AppConstants.backgroundRefreshInterval

    /// Schedule the next background refresh task
    func scheduleNextRefresh() {
        let targetDate = Date().addingTimeInterval(preferredInterval)
        WKApplication.shared().scheduleBackgroundRefresh(
            withPreferredDate: targetDate,
            userInfo: nil
        ) { error in
            if let error {
                print("[BackgroundTaskScheduler] Failed to schedule BG refresh: \(error.localizedDescription)")
            } else {
                print("[BackgroundTaskScheduler] Scheduled next refresh for \(targetDate)")
            }
        }
    }
}
