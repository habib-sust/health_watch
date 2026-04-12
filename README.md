# HealthWatch

A dual-target iOS + watchOS application for continuous health monitoring. Apple Watch collects HealthKit data and streams it to a backend; the paired iOS app provides a real-time dashboard for clinicians or caregivers managing multiple individuals.

## Overview

```
iOS App (HealthWatch)          watchOS App (HealthWatchApp Watch App)
─────────────────────          ──────────────────────────────────────
Dashboard                      HealthKit collection (background)
Alerts                         CoreData local buffer
Settings                       Background URL session push
Provisioning flow  ──Server──  Provisioning flow
```

## Features

### iOS
- **Dashboard** — card-based view of all monitored individuals with live status indicators
- **Individual detail** — per-metric charts and historical readings
- **Alerts** — surfaced anomalies from the backend
- **Provisioning** — scan a QR code or enter a device code to link a Watch to an individual record via server-side mapping

### watchOS
- **HealthKit collection** — heart rate, resting heart rate, HRV, SpO2, step count, active energy, respiratory rate, walking heart rate average, and sleep analysis
- **Background delivery** — observer queries wake the app immediately when new samples arrive
- **Offline buffering** — samples are persisted to CoreData and retried on next cycle if a push fails; buffer auto-purges after 7 days
- **Background URL session** — uploads survive Watch process suspension
- **Deduplication** — UUID-keyed cache (10 000 entries) prevents double-sending samples across cycles
- **Status view** — last sync time and sync state visible on the Watch face

## Architecture

### Provisioning flow

```
Watch shows device code (8-char hex)
       │
       ▼ Watch polls GET /api/v1/device/{id}/config every 5s
iOS selects individual, scans QR code or enters code manually
       │
       ▼ POST /api/v1/device/register { deviceId, individualId }
Server stores device-to-individual mapping
       │
       ▼ Watch poll returns "provisioned" with config
Watch stores config in Keychain, transitions to .provisioned
```

No WCSession dependency for provisioning — any iPhone with the app can provision any Watch. Polling times out after **5 minutes**.

### Data push pipeline (watchOS)

1. `HealthKitCollector` fetches new samples via anchored object queries
2. New samples are merged with any previously buffered (failed) samples
3. Combined batch is capped at **500 samples** per cycle
4. Payload is written to a temp file and uploaded via a `URLSessionConfiguration.background` task
5. On HTTP 2xx: CoreData buffer for that batch is cleared
6. On failure: buffer is retained and retried next cycle
7. On HTTP 401: Watch transitions to `.error(.tokenRevoked)` state

### Key types

| Type | Target | Role |
|---|---|---|
| `APIClient` | iOS | Swift `actor`; async/await; Bearer token auth |
| `WatchConnectivityManager` | iOS | WCSession delegate; sends/receives `ProvisioningMessage` |
| `WatchConnectivityHandler` | watchOS | WCSession delegate; drives `WatchAppState` transitions |
| `WatchAppState` | watchOS | Observable state machine: `.unprovisioned` / `.showingCode` / `.provisioned` / `.error` |
| `HealthKitCollector` | watchOS | Authorization, observer queries, anchored fetches, deduplication |
| `LocalBufferManager` | watchOS | CoreData read/write for offline sample buffer |
| `DataPushService` | watchOS | Assembles batch, background URL session upload |
| `BackgroundTaskScheduler` | watchOS | Schedules `WKApplicationRefreshBackgroundTask` every **15 minutes** |
| `KeychainManager` | both | Shared Keychain access group for provisioning config |

## Project structure

```
HealthWatch/
├── App/                        iOS entry point, MainTabView
├── Features/
│   ├── Dashboard/              IndividualCardView, DashboardViewModel
│   ├── IndividualDetail/       Charts, MetricRowView
│   ├── Alerts/                 AlertsView, AlertsViewModel
│   ├── Settings/               SettingsView
│   └── Provisioning/           QRScannerView, ProvisioningViewModel
├── Shared/
│   ├── Models/                 HealthSample, HealthPayload, ProvisioningMessage, Individual
│   ├── Networking/             APIClient, Endpoint, RetryPolicy, JSONCoders
│   ├── Security/               KeychainManager, TokenStore
│   └── Constants/              AppConstants, HealthKitTypes
├── Services/                   WatchConnectivityManager, ErrorHandler, AppLogger
└── Mock/                       MockIndividuals, MockHealthData

HealthWatchApp Watch App/
├── App/                        Entry point, ExtensionDelegate
├── Features/
│   ├── Provisioning/           WatchUnprovisionedView, WatchProvisionCodeView, WatchErrorView
│   ├── Status/                 WatchStatusView
│   └── HealthData/             WatchHealthDataView, WatchMetricCardView, WatchProvisionedTabView
├── Persistence/                CoreDataStack, BufferedHealthSample
├── Services/                   HealthKitCollector, DataPushService, LocalBufferManager,
│                               BackgroundTaskScheduler, HeartbeatService,
│                               DeviceConfigPoller, WatchConnectivityHandler,
│                               WatchAppState, WatchLogger
└── Shared/                     (mirrors iOS shared layer)

HealthWatchTests/
    KeychainManagerTests, ProvisioningViewModelTests, DashboardViewModelTests,
    IndividualModelTests, MockHealthDataTests, JSONCodingTests, ErrorHandlerTests
```

## Configuration

`DemoConfiguration.swift` holds hardcoded credentials for the demo build. Replace with real authentication before shipping to production.

| Constant | Default |
|---|---|
| `serverURL` | `https://dev-api.healthwatch.example` |
| `apiToken` | `demo-token-healthwatch-2026` |
| `watchAuthToken` | `demo-watch-token-healthwatch-2026` |

`AppConstants.swift` contains all tuneable parameters (polling intervals, buffer limits, timeout values, etc.).

## Requirements

- Xcode 16+
- iOS 17+ (iPhone)
- watchOS 10+ (Apple Watch)
- HealthKit entitlement on the watchOS target
- WatchConnectivity entitlement on both targets
- Shared Keychain access group: `com.company.healthwatch.shared`

## Getting started

1. Clone the repository and open `HealthWatch.xcodeproj` in Xcode.
2. Update the bundle identifier and team in both target signing settings.
3. Set `DemoConfiguration.serverURL` to point at your backend.
4. Build and run the **HealthWatch** scheme on an iPhone simulator or device.
5. Build and run the **HealthWatchApp Watch App** scheme on a paired Watch.
6. On the Watch, tap **Provision** to display a device code. On the iPhone, open the Provisioning tab, select an individual, and scan the code or enter it manually.

## Testing

Unit tests live in `HealthWatchTests/`. Run them with `Cmd+U` in Xcode or:

```bash
xcodebuild test -scheme HealthWatch -destination 'platform=iOS Simulator,name=iPhone 16'
```
