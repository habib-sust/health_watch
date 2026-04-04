import WatchKit

final class ExtensionDelegate: NSObject, WKApplicationDelegate {

    func applicationDidFinishLaunching() {
        // Restore HealthKit anchors from previous session
        HealthKitCollector.shared.restoreAnchors()
    }

    func handle(_ backgroundTasks: Set<WKRefreshBackgroundTask>) {
        for task in backgroundTasks {
            switch task {
            case let refreshTask as WKApplicationRefreshBackgroundTask:
                handleRefreshTask(refreshTask)

            case let urlTask as WKURLSessionRefreshBackgroundTask:
                // Wake up the background URLSession so it can handle completion
                let _ = DataPushService.shared.handleBackgroundURLSession(
                    identifier: urlTask.sessionIdentifier
                )
                urlTask.setTaskCompletedWithSnapshot(false)

            default:
                task.setTaskCompletedWithSnapshot(false)
            }
        }
    }

    private func handleRefreshTask(_ task: WKApplicationRefreshBackgroundTask) {
        // Schedule the next refresh immediately so we don't miss cycles
        BackgroundTaskScheduler.shared.scheduleNextRefresh()

        // Purge expired buffered data
        LocalBufferManager.shared.purgeExpired()

        // Collect and push health data, then send heartbeat
        Task {
            await DataPushService.shared.collectAndPush()
            await HeartbeatService.shared.sendHeartbeat()
            task.setTaskCompletedWithSnapshot(false)
        }
    }
}
