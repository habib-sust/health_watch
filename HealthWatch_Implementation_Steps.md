# HealthWatch Demo — Step-by-Step Implementation Flow

> Derived from the HealthWatch Implementation Guide (Demo Build) v1.0

---

## Phase 1: Foundation (Weeks 1–2)

### Step 1 — Project Setup & Structure
- Create the Xcode workspace with iOS target (`HealthWatch`) and watchOS target (`HealthWatchApp`)
- Set up the folder structure: `App/`, `Features/`, `Services/`, `Mock/`, `Resources/`, `Supporting/` for each target
- Create the `HealthWatchShared` Swift Package under `Packages/` with `Models/`, `Networking/`, `Security/`, `Constants/` folders
- Configure bundle IDs, deployment targets (iOS 16.0, watchOS 9.0), and capabilities (HealthKit, Background Modes, Keychain Sharing, Push Notifications)
- Set up the shared Keychain access group: `$(TeamIdentifierPrefix)com.company.healthwatch.shared`
- Configure entitlements files for both targets

### Step 2 — CI & Tooling
- Add SPM dependencies: `KeychainAccess`, `swift-log`
- Set up SwiftLint (`0.54+`) and build schemes (Demo, Staging, Production)
- Set up Fastlane for build automation
- Configure code signing (automatic for dev, manual for CI)

### Step 3 — Shared Models
- Implement `HealthSample` (Codable, Identifiable — with id, typeIdentifier, value, unit, dates, sourceBundleId)
- Implement `HealthPayload` (individualId, deviceId, timestamp, samples array, batchId for idempotency)
- Implement `ProvisioningMessage` + `ProvisioningMessageType` enum (initiate, codeEntry, codeVerified, codeFailed, ack)
- Implement error types: `APIError`, `WatchError`, `ProvisioningError`
- Define `HealthKitTypes` constants and `AppConstants`

### Step 4 — Security & Networking Foundation
- Implement `KeychainManager` (save/load/delete with convenience methods for serverURL, individualId, authToken)
- Implement `ProvisioningConfig` struct
- Implement `TokenStore` protocol + `StaticTokenStore` (returns hardcoded demo token)
- Implement `APIClient` (actor-based, URLSession, Bearer auth, HTTP status code handling)
- Implement `Endpoint` struct with static factory methods (getIndividuals, getHealth, pushHealthData, heartbeat, etc.)
- Implement `RetryPolicy` with exponential backoff + jitter
- Stub `CertificatePinningDelegate` (placeholder for demo)

### Step 5 — Demo Configuration
- Create `DemoConfiguration.swift` — hardcoded staffId, staffName, serverURL, apiToken, watchAuthToken
- Create `MockIndividuals.swift` — 5 hardcoded individuals (Alice, Bob, Carol, David, Eva)
- Create `MockHealthData.swift` — sample health data for charts

**Exit criteria:** Both targets build. API client makes authenticated requests with the demo token. Mock data is available.

---

## Phase 2: Provisioning (Weeks 3–5)

### Step 6 — WatchConnectivity Bridge (iOS Side)
- Implement `WatchConnectivityManager` as an `ObservableObject`
- Activate `WCSession`, set delegate
- Publish `isWatchReachable`
- Implement `send(_ message: ProvisioningMessage)` — encode to JSON, send via `WCSession.sendMessage`
- Handle incoming messages: `.codeEntry` → `onCodeReceived` callback, `.ack` → `onAckReceived` callback
- Implement required iOS stubs: `sessionDidBecomeInactive`, `sessionDidDeactivate`

### Step 7 — WatchConnectivity Bridge (watchOS Side)
- Implement `WatchConnectivityHandler` as a singleton `ObservableObject`
- Implement `activate()`, `sendCodeToiOS(_ code:)`, `sendAck()`
- Handle incoming messages: `.initiate` → `onProvisioningInitiated`, `.codeVerified` → store config in Keychain + send ACK + `onConfigReceived`, `.codeFailed` → `onCodeFailed`
- Add `transferUserInfo` fallback for message reliability

### Step 8 — Provisioning State Machine (iOS)
- Implement `ProvisioningState` enum (selectIndividual, checkingWatchConnection, watchNotReachable, displayingCode, waitingForCodeEntry, verifyingCode, codeAccepted, codeFailed, sendingConfig, success, locked, error)
- Implement `ProvisioningViewModel`:
  - Load individuals from `MockIndividuals.all`
  - `generateCode()` — 4-digit code using `SecRandomCopyBytes`, 120-second expiry
  - `verifyCode()` — compare entered code, check expiry
  - `initiateProvisioning()` — check watch reachability → display code → send `.initiate` message
  - `handleCodeFromWatch()` — verify → send config or increment failures (lockout after 3)
  - `sendConfiguration()` — build `ProvisioningMessage` with `DemoConfiguration` values and send

### Step 9 — Provisioning UI (iOS)
- Build `ProvisioningView` — multi-step wizard driven by `ProvisioningState`
- Build `CodeDisplayView` — shows the 4-digit code with countdown timer
- Build `ProvisioningStatusView` — shows progress/success/error states

### Step 10 — Provisioning UI (watchOS)
- Implement `WatchAppState` with `WatchMode` enum (unprovisioned, provisioning, provisioned, error)
- Implement `HealthWatchWatchApp` — routes UI based on `WatchMode`
- Build `AwaitingSetupView` — shown when unprovisioned
- Build `WatchCodeEntryView` — shows individual name, 4-digit SecureField, Confirm button
- Build `WatchErrorView` — shows error state

**Exit criteria:** Staff can select a mock individual, provision a watch via code entry, watch stores config in Keychain and enters provisioned mode.

---

## Phase 3: Data Collection (Weeks 6–8)

### Step 11 — HealthKit Authorization
- Implement `HealthKitCollector` singleton
- Define `readTypes`: heartRate, restingHeartRate, heartRateVariabilitySDNN, oxygenSaturation, stepCount, activeEnergyBurned, respiratoryRate, walkingHeartRateAverage, sleepAnalysis
- Implement `requestAuthorization()` (async)
- Implement `authorizationStatus(for:)` and `deniedTypes()`

### Step 12 — HealthKit Observer + Anchored Queries
- Implement `enableBackgroundDelivery()` — register observers for each authorized type with `.immediate` frequency
- Implement `HKObserverQuery` per type — triggers `fetchNewSamples` on update
- Implement `fetchNewSamples(for:)` using `HKAnchoredObjectQuery` with persisted anchors
- Implement `convertToHealthSample()` — handle both `HKQuantitySample` and `HKCategorySample`
- Persist anchors to UserDefaults for cold-start recovery

### Step 13 — De-duplication
- Track recently transmitted sample UUIDs in UserDefaults (capped at 10,000, rolling)
- Check UUIDs before buffering to prevent duplicates

### Step 14 — Core Data Buffer (watchOS)
- Create `HealthDataBuffer.xcdatamodeld` with `BufferedHealthSample` entity (id, batchId, typeIdentifier, value, unit, startDate, endDate, sourceBundleId, bufferedAt, transmitted)
- Implement `CoreDataStack` with file protection (`completeUntilFirstUserAuthentication`)
- Implement `LocalBufferManager` singleton:
  - `buffer(_ samples:, batchId:)` — save to Core Data
  - `loadBuffered()` — fetch untransmitted, limit 500, sorted by bufferedAt
  - `clearBatch(_ batchId:)` — delete transmitted batch
  - `purgeExpired()` — delete samples older than 7 days
  - `clearAllBufferedData()` — batch delete all (for re-provisioning)

### Step 15 — Background Task Scheduling
- Implement `BackgroundTaskScheduler` singleton
- `scheduleNextRefresh()` — schedule `WKApplicationRefreshBackgroundTask` every 15 minutes
- Implement `ExtensionDelegate`:
  - `applicationDidFinishLaunching()` — activate WatchConnectivity, schedule first refresh
  - `handle(_ backgroundTasks:)` — on refresh: collect & push, reschedule, complete task

### Step 16 — Data Push Service
- Implement `DataPushService` singleton with background `URLSession`
- `collectAndPush()`:
  1. Fetch new samples from HealthKit
  2. Load buffered samples from Core Data
  3. Combine and de-duplicate
  4. Build `HealthPayload` with config from Keychain
  5. Serialize to temp file, upload via background session
  6. Buffer locally as safety net
- Handle completion: 2xx → clear batch, 401 → enter token-revoked error state, other → leave buffered for retry

**Exit criteria:** Provisioned watch autonomously collects HealthKit samples and pushes to demo server every ~15 min with local buffering on failure.

---

## Phase 4: Staff Monitoring (Weeks 9–11)

### Step 17 — App Lifecycle & Navigation (iOS)
- Implement `HealthWatchApp.swift` — `@main`, inject `WatchConnectivityManager` as environment object
- Build `MainTabView` with tabs: Dashboard, Alerts, Provisioning, Settings

### Step 18 — Dashboard
- Implement `DashboardViewModel`:
  - Pre-populate with `MockIndividuals.all` (never empty dashboard)
  - `startPolling()` — poll `GET /api/v1/individuals` every 60 seconds
  - `refresh()` — async fetch, keep mock data on failure
  - Support `.refreshable` pull-to-refresh
- Build `DashboardView` — `LazyVGrid` of individual status cards
- Build `IndividualCardView` — name, last sync timestamp, color-coded status dot
- Build `StatusIndicator` — green (normal), yellow (attention), gray (offline)

### Step 19 — Individual Detail
- Implement `IndividualDetailViewModel`:
  - Fetch from `GET /api/v1/individuals/{id}/health` with date range + metric type
  - Time range selector: Last 24 Hours (default), Last 7 Days, Last 30 Days
- Build `IndividualDetailView` with sections: Vitals (heart rate, SpO2, respiratory rate), Activity (steps, energy), Sleep
- Build `HealthMetricChartView` using Swift Charts (`LineMark` / `BarMark`)
- Build `MetricRowView` for individual metric display

### Step 20 — Alerts & Notifications
- Implement `AlertsViewModel` — fetch from `GET /api/v1/alerts`
- Build `AlertsView` and `AlertConfigView` — threshold configuration
- Implement `NotificationService` — push notifications for threshold breaches

### Step 21 — Settings & Watch Status
- Build `SettingsView` + `SettingsViewModel`
- Build `WatchStatusView` (watchOS) — sync status icon, time since last sync, individual name
- Build `SyncStatusIndicator` — checkmark/spinner/warning

**Exit criteria:** Staff can view real-time and historical health data on their iPhone. Dashboard shows mock data and updates from server when available.

---

## Phase 5: Demo Polish & Testing (Weeks 12–14)

### Step 22 — Error Recovery
- Implement watch recovery state machine: normal → buffering on network failure → retry next cycle
- Handle 401 → token revoked state → require re-provisioning
- Handle storage full → purge oldest → resume
- Cold start recovery → load config from Keychain, anchors from UserDefaults
- Re-provisioning → clear all buffered data → store new config
- iOS: centralized error handler mapping `APIError` to user-facing messages

### Step 23 — Logging & Observability
- Set up `Logger` extensions with subsystems: provisioning, healthkit, networking, buffer, sync
- Implement watch heartbeat (`POST /api/v1/device/heartbeat`) with device ID, battery level, buffer size, last push timestamp

### Step 24 — Accessibility & Polish
- Add VoiceOver labels to all interactive elements
- Support Dynamic Type
- Dark mode polish
- Verify UI on multiple device sizes

### Step 25 — Testing
- **Unit tests:** ProvisioningViewModel (code gen, expiry, lockout, state transitions), HealthKitCollector (conversion, dedup, anchors), LocalBufferManager (buffer/retrieve/clear, purge, wipe), APIClient (401, retry, JSON), KeychainManager (save/load/delete), DataPushService (payload, batch ID, empty handling)
- **Integration tests (hardware):** Full provisioning flow, end-to-end data push, buffering under network loss, 401 recovery, re-provisioning
- **UI tests:** Dashboard rendering, pull-to-refresh, chart interaction, provisioning wizard, watch code entry
- **Performance tests:** Background task < 15s, Core Data fetch 500 samples, payload serialization, dashboard launch time with 200 individuals

### Step 26 — 24-Hour Soak Test & Demo Rehearsal
- Run the full system on physical hardware for 24+ hours
- Validate background execution isn't being throttled
- Rehearse the demo script end-to-end

**Exit criteria:** Complete demo-ready build. All features functional on physical iPhone + Apple Watch. Demo script validated.

---

## Summary

| Phase | Steps | Focus | Timeline |
|---|---|---|---|
| 1 — Foundation | Steps 1–5 | Project structure, shared models, networking, demo config | Weeks 1–2 |
| 2 — Provisioning | Steps 6–10 | WatchConnectivity bridge, state machine, code verification UI | Weeks 3–5 |
| 3 — Data Collection | Steps 11–16 | HealthKit, Core Data buffer, background tasks, data push | Weeks 6–8 |
| 4 — Staff Monitoring | Steps 17–21 | Dashboard, charts, alerts, settings | Weeks 9–11 |
| 5 — Demo Polish | Steps 22–26 | Error recovery, logging, accessibility, testing, soak test | Weeks 12–14 |

**Total: 26 Steps across 5 Phases (14 Weeks)**

---

*Derived from HealthWatch Implementation Guide (Demo Build) v1.0 — April 2026*
