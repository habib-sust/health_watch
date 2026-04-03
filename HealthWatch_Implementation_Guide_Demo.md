# HEALTHWATCH — Implementation Guide (Demo Build)
## iOS & watchOS Health Monitoring Platform

---

| Field | Value |
|---|---|
| **Document Title** | Implementation Guide (Demo Build) |
| **Project Name** | HealthWatch — iOS & watchOS Health Monitoring Platform |
| **Version** | 1.0-demo |
| **Date** | April 2, 2026 |
| **Status** | Draft |
| **Specification Reference** | HealthWatch Project Specification v1.0 |

> **Demo Scope:** This build skips authentication entirely. The iOS app launches directly to the dashboard with a hardcoded staff identity and a pre-configured list of individuals. The provisioning flow, data collection, watch communication, and monitoring features are fully functional. Authentication will be layered in for the production build.

---

## Table of Contents

1. [Project Setup & Structure](#1-project-setup--structure)
2. [Development Environment](#2-development-environment)
3. [Shared Module — Models & Networking](#3-shared-module--models--networking)
4. [iOS App Implementation](#4-ios-app-implementation)
5. [watchOS App Implementation](#5-watchos-app-implementation)
6. [WatchConnectivity — Provisioning Bridge](#6-watchconnectivity--provisioning-bridge)
7. [HealthKit Integration](#7-healthkit-integration)
8. [Background Execution & Scheduling](#8-background-execution--scheduling)
9. [Local Data Buffering (watchOS)](#9-local-data-buffering-watchos)
10. [Networking Layer](#10-networking-layer)
11. [Security Implementation](#11-security-implementation)
12. [Error Handling & Recovery](#12-error-handling--recovery)
13. [Testing Strategy](#13-testing-strategy)
14. [CI/CD & Build Configuration](#14-cicd--build-configuration)
15. [Logging & Observability](#15-logging--observability)
16. [App Store & Distribution](#16-app-store--distribution)
17. [Implementation Phases & Timeline](#17-implementation-phases--timeline)

---

## 1. Project Setup & Structure

### 1.1 Xcode Project Organization

The project uses a single Xcode workspace containing an iOS app target, a watchOS app target, and shared Swift packages.

```
HealthWatch/
├── HealthWatch.xcworkspace
├── HealthWatch/                          # iOS App Target
│   ├── App/
│   │   ├── HealthWatchApp.swift          # @main entry point
│   │   ├── AppDelegate.swift             # UIKit lifecycle hooks
│   │   └── SceneDelegate.swift
│   ├── Features/
│   │   ├── Dashboard/
│   │   │   ├── DashboardView.swift
│   │   │   ├── DashboardViewModel.swift
│   │   │   ├── IndividualCardView.swift
│   │   │   └── StatusIndicator.swift
│   │   ├── IndividualDetail/
│   │   │   ├── IndividualDetailView.swift
│   │   │   ├── IndividualDetailViewModel.swift
│   │   │   ├── HealthMetricChartView.swift
│   │   │   └── MetricRowView.swift
│   │   ├── Provisioning/
│   │   │   ├── ProvisioningView.swift
│   │   │   ├── ProvisioningViewModel.swift
│   │   │   ├── CodeDisplayView.swift
│   │   │   └── ProvisioningStatusView.swift
│   │   ├── Alerts/
│   │   │   ├── AlertsView.swift
│   │   │   ├── AlertsViewModel.swift
│   │   │   └── AlertConfigView.swift
│   │   └── Settings/
│   │       ├── SettingsView.swift
│   │       └── SettingsViewModel.swift
│   ├── Services/
│   │   ├── WatchConnectivityManager.swift
│   │   ├── NotificationService.swift
│   │   └── DemoConfiguration.swift       # Hardcoded staff & server config
│   ├── Mock/
│   │   ├── MockIndividuals.swift          # Hardcoded individual list
│   │   └── MockHealthData.swift           # Sample health data for demo
│   ├── Resources/
│   │   ├── Assets.xcassets
│   │   ├── Info.plist
│   │   └── Localizable.strings
│   └── Supporting/
│       └── HealthWatch.entitlements
├── HealthWatchWatch/                     # watchOS App Target
│   ├── App/
│   │   └── HealthWatchWatchApp.swift     # @main entry point
│   ├── Features/
│   │   ├── Provisioning/
│   │   │   ├── WatchCodeEntryView.swift
│   │   │   └── AwaitingSetupView.swift
│   │   └── Status/
│   │       ├── WatchStatusView.swift
│   │       └── SyncStatusIndicator.swift
│   ├── Services/
│   │   ├── WatchConnectivityHandler.swift
│   │   ├── HealthKitCollector.swift
│   │   ├── DataPushService.swift
│   │   ├── BackgroundTaskScheduler.swift
│   │   └── LocalBufferManager.swift
│   ├── Persistence/
│   │   ├── HealthDataBuffer.xcdatamodeld
│   │   └── CoreDataStack.swift
│   ├── Resources/
│   │   ├── Assets.xcassets
│   │   └── Info.plist
│   └── Supporting/
│       └── HealthWatchWatch.entitlements
├── Packages/
│   └── HealthWatchShared/                # Swift Package — shared code
│       ├── Package.swift
│       └── Sources/
│           └── HealthWatchShared/
│               ├── Models/
│               │   ├── Individual.swift
│               │   ├── HealthSample.swift
│               │   ├── HealthPayload.swift
│               │   ├── ProvisioningMessage.swift
│               │   └── APIError.swift
│               ├── Networking/
│               │   ├── APIClient.swift
│               │   ├── Endpoint.swift
│               │   └── RequestBuilder.swift
│               ├── Security/
│               │   ├── KeychainManager.swift
│               │   └── TokenStore.swift
│               └── Constants/
│                   ├── HealthKitTypes.swift
│                   └── AppConstants.swift
└── Tests/
    ├── HealthWatchTests/                 # iOS unit tests
    ├── HealthWatchWatchTests/            # watchOS unit tests
    └── HealthWatchUITests/              # UI tests
```

**Key differences from production structure:** No `Auth/` feature folder. Added `Mock/` folder for hardcoded demo data. `SessionManager.swift` replaced by `DemoConfiguration.swift`.

### 1.2 Target Configuration

| Target | Bundle ID | Deployment Target | Capabilities |
|---|---|---|---|
| HealthWatch (iOS) | com.company.healthwatch | iOS 16.0 | Push Notifications, Keychain Sharing, Background Modes (Remote notifications) |
| HealthWatchWatch (watchOS) | com.company.healthwatch.watchkitapp | watchOS 9.0 | HealthKit, Background Modes (Background refresh, Remote notifications), Keychain Sharing |

### 1.3 Keychain Access Group

Both targets share a Keychain access group `$(TeamIdentifierPrefix)com.company.healthwatch.shared` for provisioning data transfer. This is only used during the provisioning step when both apps are on the same paired device set.

---

## 2. Development Environment

### 2.1 Required Tools

| Tool | Minimum Version | Purpose |
|---|---|---|
| Xcode | 15.0+ | Primary IDE |
| Swift | 5.9+ | Programming language |
| macOS | Sonoma 14.0+ | Build host |
| CocoaPods / SPM | Latest | Dependency management (prefer SPM) |
| SwiftLint | 0.54+ | Code style enforcement |
| Fastlane | 2.220+ | Build automation & distribution |

### 2.2 Third-Party Dependencies

| Dependency | Purpose | Integration |
|---|---|---|
| Swift Package: KeychainAccess | Simplified Keychain wrapper | SPM |
| Swift Package: swift-log | Structured logging | SPM |
| Charts (Swift Charts) | Health metric visualization (iOS 16+) | Native framework |

Keep dependencies minimal. HealthKit, WatchConnectivity, Core Data, and URLSession are all native frameworks with no third-party alternatives needed.

### 2.3 Physical Hardware Requirements

watchOS development and testing requires physical Apple Watch hardware. The Xcode simulator does not support HealthKit data generation, WatchConnectivity message delivery testing, or background task scheduling behavior. Every developer on the team needs access to at least one iPhone + Apple Watch pair.

---

## 3. Shared Module — Models & Networking

### 3.1 Core Models

```swift
// HealthWatchShared/Models/HealthSample.swift

import Foundation

struct HealthSample: Codable, Identifiable {
    let id: UUID
    let typeIdentifier: String   // e.g. "HKQuantityTypeIdentifierHeartRate"
    let value: Double
    let unit: String             // e.g. "count/min"
    let startDate: Date
    let endDate: Date
    let sourceBundleId: String
}
```

```swift
// HealthWatchShared/Models/HealthPayload.swift

import Foundation

struct HealthPayload: Codable {
    let individualId: String
    let deviceId: String
    let timestamp: Date
    let samples: [HealthSample]
    let batchId: UUID            // For idempotent server-side processing
}
```

```swift
// HealthWatchShared/Models/ProvisioningMessage.swift

import Foundation

enum ProvisioningMessageType: String, Codable {
    case initiate        // iOS → Watch: start provisioning
    case codeEntry       // Watch → iOS: user entered code
    case codeVerified    // iOS → Watch: code accepted, here's config
    case codeFailed      // iOS → Watch: code rejected
    case ack             // Watch → iOS: config stored successfully
}

struct ProvisioningMessage: Codable {
    let type: ProvisioningMessageType
    let code: String?
    let serverURL: String?
    let individualId: String?
    let authToken: String?
    let individualName: String?  // For watch display/confirmation
    let timestamp: Date
}
```

### 3.2 API Client

```swift
// HealthWatchShared/Networking/APIClient.swift

import Foundation

actor APIClient {
    private let session: URLSession
    private let baseURL: URL
    private let tokenStore: TokenStore

    init(baseURL: URL, tokenStore: TokenStore) {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)
        self.baseURL = baseURL
        self.tokenStore = tokenStore
    }

    func send<T: Decodable>(_ endpoint: Endpoint) async throws -> T {
        var request = try endpoint.urlRequest(baseURL: baseURL)

        // Demo: use hardcoded token from DemoConfiguration
        if let token = await tokenStore.currentToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        switch http.statusCode {
        case 200...299:
            return try JSONDecoder.healthWatch.decode(T.self, from: data)
        case 401:
            throw APIError.unauthorized
        case 429:
            throw APIError.rateLimited(retryAfter: http.value(forHTTPHeaderField: "Retry-After"))
        case 500...599:
            throw APIError.serverError(statusCode: http.statusCode)
        default:
            throw APIError.httpError(statusCode: http.statusCode, data: data)
        }
    }
}
```

### 3.3 Keychain Manager

```swift
// HealthWatchShared/Security/KeychainManager.swift

import Foundation
import Security

struct KeychainManager {
    private let service: String

    init(service: String = "com.company.healthwatch") {
        self.service = service
    }

    func save(_ data: Data, for key: String) throws { /* SecItemAdd / SecItemUpdate */ }
    func load(for key: String) throws -> Data? { /* SecItemCopyMatching */ }
    func delete(for key: String) throws { /* SecItemDelete */ }

    // Convenience methods for common provisioning values
    func saveServerURL(_ url: String) throws { /* ... */ }
    func saveIndividualId(_ id: String) throws { /* ... */ }
    func saveAuthToken(_ token: String) throws { /* ... */ }
    func loadProvisioningConfig() throws -> ProvisioningConfig? { /* ... */ }
    func clearAll() throws { /* ... */ }
}

struct ProvisioningConfig {
    let serverURL: String
    let individualId: String
    let authToken: String
}
```

---

## 4. iOS App Implementation

### 4.1 Demo Configuration & Hardcoded Identity

Since authentication is skipped for the demo, the app uses a hardcoded staff identity and server configuration. This is centralized in a single file that will be replaced by real auth in the production build.

```swift
// HealthWatch/Services/DemoConfiguration.swift

import Foundation

struct DemoConfiguration {
    /// Hardcoded staff identity — replaces AuthManager for demo
    static let staffId = "staff-demo-001"
    static let staffName = "Demo Staff"

    /// Server URL — configure to point at your demo backend
    static let serverURL = "https://dev-api.healthwatch.example"

    /// Hardcoded bearer token for API calls (demo server must accept this)
    static let apiToken = "demo-token-healthwatch-2026"

    /// Watch-scoped token issued during provisioning
    /// In production this comes from POST /api/v1/individuals/{id}/provision
    static let watchAuthToken = "demo-watch-token-healthwatch-2026"
}
```

```swift
// HealthWatch/Mock/MockIndividuals.swift

import Foundation

struct MockIndividuals {
    /// Pre-loaded list — in production this comes from GET /api/v1/individuals
    static let all: [Individual] = [
        Individual(id: "ind-001", name: "Alice Johnson", status: .normal),
        Individual(id: "ind-002", name: "Bob Martinez", status: .normal),
        Individual(id: "ind-003", name: "Carol Chen", status: .attention),
        Individual(id: "ind-004", name: "David Park", status: .offline),
        Individual(id: "ind-005", name: "Eva Williams", status: .normal),
    ]
}
```

### 4.2 App Lifecycle (No Auth Gate)

The app launches directly into the main tab view. No login screen, no auth check.

```swift
// HealthWatch/App/HealthWatchApp.swift

import SwiftUI

@main
struct HealthWatchApp: App {
    @StateObject private var watchManager = WatchConnectivityManager()

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(watchManager)
        }
    }
}
```

### 4.3 Dashboard Implementation

The dashboard uses a `LazyVGrid` of individual status cards. Each card shows the individual's name, last sync timestamp, and a color-coded status dot. For the demo, the initial list is loaded from `MockIndividuals.all`, then refreshed from the server if available. The view model polls `GET /api/v1/individuals` every 60 seconds and supports pull-to-refresh via SwiftUI's `.refreshable` modifier.

```swift
// HealthWatch/Features/Dashboard/DashboardViewModel.swift

@MainActor
final class DashboardViewModel: ObservableObject {
    @Published var individuals: [IndividualSummary] = []
    @Published var isLoading = false
    @Published var error: APIError?

    private let apiClient: APIClient
    private var pollingTask: Task<Void, Never>?

    init() {
        // Initialize API client with demo config
        let url = URL(string: DemoConfiguration.serverURL)!
        let tokenStore = StaticTokenStore(token: DemoConfiguration.apiToken)
        self.apiClient = APIClient(baseURL: url, tokenStore: tokenStore)

        // Pre-populate with mock data so dashboard is never empty
        self.individuals = MockIndividuals.all.map { $0.toSummary() }
    }

    func startPolling() {
        pollingTask = Task {
            while !Task.isCancelled {
                await refresh()
                try? await Task.sleep(for: .seconds(60))
            }
        }
    }

    func refresh() async {
        isLoading = individuals.isEmpty
        do {
            individuals = try await apiClient.send(.getIndividuals())
            error = nil
        } catch let err as APIError {
            // On failure, keep showing mock data — don't blank the dashboard
            error = err
        } catch {}
        isLoading = false
    }

    func stopPolling() {
        pollingTask?.cancel()
    }
}
```

```swift
// HealthWatchShared/Security/TokenStore.swift — Demo variant

/// Static token store for demo — always returns the hardcoded token
final class StaticTokenStore: TokenStore {
    private let token: String
    init(token: String) { self.token = token }
    func currentToken() async -> String? { token }
}
```

### 4.4 Individual Detail View

The detail view presents health data using Swift Charts. Organize metrics into sections: vitals (heart rate, SpO₂, respiratory rate), activity (steps, active energy), and sleep. Each section uses a `Chart` view with `LineMark` or `BarMark` as appropriate. Data is fetched from `GET /api/v1/individuals/{id}/health` with query parameters for date range and metric type.

Time range selector options: Last 24 Hours, Last 7 Days, Last 30 Days. Default to Last 24 Hours.

### 4.5 Provisioning Screen

The provisioning screen is a multi-step wizard managed by a state machine. For the demo, the individual selection step uses the hardcoded `MockIndividuals.all` list, and the configuration payload uses `DemoConfiguration.serverURL` and `DemoConfiguration.watchAuthToken` instead of requesting a token from the server.

```swift
// HealthWatch/Features/Provisioning/ProvisioningViewModel.swift

enum ProvisioningState {
    case selectIndividual
    case checkingWatchConnection
    case watchNotReachable
    case displayingCode(code: String, expiresAt: Date)
    case waitingForCodeEntry
    case verifyingCode
    case codeAccepted
    case codeFailed(attemptsRemaining: Int)
    case sendingConfig
    case success
    case locked(unlockAt: Date)
    case error(ProvisioningError)
}

@MainActor
final class ProvisioningViewModel: ObservableObject {
    @Published var state: ProvisioningState = .selectIndividual
    @Published var selectedIndividual: Individual?

    /// Demo: individuals loaded from mock data
    let availableIndividuals = MockIndividuals.all

    private let watchManager: WatchConnectivityManager
    private var generatedCode: String?
    private var codeGeneratedAt: Date?
    private var failedAttempts = 0
    private let maxAttempts = 3
    private let codeExpirySeconds: TimeInterval = 120

    func generateCode() -> String {
        let code = String(format: "%04d", Int.random(in: 0...9999))
        generatedCode = code
        codeGeneratedAt = Date()
        return code
    }

    func verifyCode(_ enteredCode: String) -> Bool {
        guard let generated = generatedCode,
              let generatedAt = codeGeneratedAt,
              Date().timeIntervalSince(generatedAt) < codeExpirySeconds
        else {
            return false // expired
        }
        return enteredCode == generated
    }

    func initiateProvisioning() async {
        state = .checkingWatchConnection

        guard watchManager.isWatchReachable else {
            state = .watchNotReachable
            return
        }

        let code = generateCode()
        state = .displayingCode(
            code: code,
            expiresAt: Date().addingTimeInterval(codeExpirySeconds)
        )

        // Send initiation message to watch
        let message = ProvisioningMessage(
            type: .initiate,
            code: nil,
            serverURL: nil,
            individualId: nil,
            authToken: nil,
            individualName: selectedIndividual?.name,
            timestamp: Date()
        )
        watchManager.send(message)
        state = .waitingForCodeEntry
    }

    func handleCodeFromWatch(_ code: String) async {
        state = .verifyingCode

        if verifyCode(code) {
            state = .codeAccepted
            await sendConfiguration()
        } else {
            failedAttempts += 1
            if failedAttempts >= maxAttempts {
                state = .locked(unlockAt: Date().addingTimeInterval(300))
            } else {
                state = .codeFailed(attemptsRemaining: maxAttempts - failedAttempts)
            }
        }
    }

    private func sendConfiguration() async {
        state = .sendingConfig

        guard let individual = selectedIndividual else { return }

        // Demo: use hardcoded server URL and watch token
        // Production: would call POST /api/v1/individuals/{id}/provision
        let configMessage = ProvisioningMessage(
            type: .codeVerified,
            code: nil,
            serverURL: DemoConfiguration.serverURL,
            individualId: individual.id,
            authToken: DemoConfiguration.watchAuthToken,
            individualName: individual.name,
            timestamp: Date()
        )

        watchManager.send(configMessage)
        // Wait for ACK from watch → handled via delegate callback → sets state = .success
    }
}
```

---

## 5. watchOS App Implementation

### 5.1 App Entry Point & State Routing

```swift
// HealthWatchWatch/App/HealthWatchWatchApp.swift

import SwiftUI
import WatchKit

@main
struct HealthWatchWatchApp: App {
    @WKApplicationDelegateAdaptor(ExtensionDelegate.self) var delegate
    @StateObject private var appState = WatchAppState()

    var body: some Scene {
        WindowGroup {
            Group {
                switch appState.mode {
                case .unprovisioned:
                    AwaitingSetupView()
                case .provisioning(let message):
                    WatchCodeEntryView(individualName: message.individualName)
                        .environmentObject(appState)
                case .provisioned:
                    WatchStatusView()
                        .environmentObject(appState)
                case .error(let error):
                    WatchErrorView(error: error)
                }
            }
            .environmentObject(appState)
        }
    }
}
```

```swift
// HealthWatchWatch/Services/WatchAppState.swift

enum WatchMode {
    case unprovisioned
    case provisioning(ProvisioningMessage)
    case provisioned
    case error(WatchError)
}

@MainActor
final class WatchAppState: ObservableObject {
    @Published var mode: WatchMode = .unprovisioned
    @Published var lastSyncDate: Date?
    @Published var syncStatus: SyncStatus = .idle

    private let keychain = KeychainManager()

    func initialize() {
        if let _ = try? keychain.loadProvisioningConfig() {
            mode = .provisioned
        } else {
            mode = .unprovisioned
        }
    }
}
```

### 5.2 Code Entry View

The watch code entry screen displays a numeric keypad optimized for the small screen. Use a `TextField` with `.numberPad` keyboard or a custom 4-digit entry using Digital Crown interaction. Show the individual's name at the top for staff to confirm they're provisioning the right person.

```swift
// HealthWatchWatch/Features/Provisioning/WatchCodeEntryView.swift

import SwiftUI

struct WatchCodeEntryView: View {
    let individualName: String?
    @EnvironmentObject var appState: WatchAppState
    @State private var enteredCode = ""
    @State private var isSubmitting = false

    var body: some View {
        VStack(spacing: 8) {
            if let name = individualName {
                Text("Setup for")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text(name)
                    .font(.headline)
                    .lineLimit(1)
            }

            Text("Enter 4-digit code")
                .font(.caption)

            SecureField("Code", text: $enteredCode)
                .multilineTextAlignment(.center)
                .font(.title2.monospacedDigit())

            Button("Confirm") {
                submitCode()
            }
            .disabled(enteredCode.count != 4 || isSubmitting)
        }
        .padding()
    }

    private func submitCode() {
        isSubmitting = true
        WatchConnectivityHandler.shared.sendCodeToiOS(enteredCode)
    }
}
```

### 5.3 Status View

The provisioned-mode status view is minimal: shows a sync status icon (checkmark, spinner, or warning triangle), the time since last successful sync, and the individual name. No health data is displayed.

### 5.4 Extension Delegate

```swift
// HealthWatchWatch/App/ExtensionDelegate.swift

import WatchKit

final class ExtensionDelegate: NSObject, WKApplicationDelegate {
    func applicationDidFinishLaunching() {
        WatchConnectivityHandler.shared.activate()
        BackgroundTaskScheduler.shared.scheduleNextRefresh()
    }

    func handle(_ backgroundTasks: Set<WKRefreshBackgroundTask>) {
        for task in backgroundTasks {
            switch task {
            case let refreshTask as WKApplicationRefreshBackgroundTask:
                Task {
                    await DataPushService.shared.collectAndPush()
                    BackgroundTaskScheduler.shared.scheduleNextRefresh()
                    refreshTask.setTaskCompletedWithSnapshot(false)
                }
            case let urlTask as WKURLSessionRefreshBackgroundTask:
                // Handle background URL session completion
                urlTask.setTaskCompletedWithSnapshot(false)
            default:
                task.setTaskCompletedWithSnapshot(false)
            }
        }
    }
}
```

---

## 6. WatchConnectivity — Provisioning Bridge

### 6.1 iOS Side — WatchConnectivityManager

```swift
// HealthWatch/Services/WatchConnectivityManager.swift

import WatchConnectivity

final class WatchConnectivityManager: NSObject, ObservableObject {
    @Published var isWatchReachable = false
    private var session: WCSession?
    var onCodeReceived: ((String) -> Void)?
    var onAckReceived: (() -> Void)?

    override init() {
        super.init()
        if WCSession.isSupported() {
            session = WCSession.default
            session?.delegate = self
            session?.activate()
        }
    }

    var isWatchReachable: Bool {
        session?.isReachable ?? false
    }

    func send(_ message: ProvisioningMessage) {
        guard let data = try? JSONEncoder().encode(message),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return }

        session?.sendMessage(dict, replyHandler: nil) { error in
            print("WCSession send error: \(error.localizedDescription)")
        }
    }
}

extension WatchConnectivityManager: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async { self.isWatchReachable = session.isReachable }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async { self.isWatchReachable = session.isReachable }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: message),
              let msg = try? JSONDecoder().decode(ProvisioningMessage.self, from: data)
        else { return }

        switch msg.type {
        case .codeEntry:
            if let code = msg.code {
                DispatchQueue.main.async { self.onCodeReceived?(code) }
            }
        case .ack:
            DispatchQueue.main.async { self.onAckReceived?() }
        default:
            break
        }
    }

    // Required stubs for iOS
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) { session.activate() }
}
```

### 6.2 watchOS Side — WatchConnectivityHandler

```swift
// HealthWatchWatch/Services/WatchConnectivityHandler.swift

import WatchConnectivity

final class WatchConnectivityHandler: NSObject, ObservableObject {
    static let shared = WatchConnectivityHandler()

    private var session: WCSession?
    var onProvisioningInitiated: ((ProvisioningMessage) -> Void)?
    var onConfigReceived: ((ProvisioningMessage) -> Void)?
    var onCodeFailed: (() -> Void)?

    func activate() {
        if WCSession.isSupported() {
            session = WCSession.default
            session?.delegate = self
            session?.activate()
        }
    }

    func sendCodeToiOS(_ code: String) {
        let message = ProvisioningMessage(
            type: .codeEntry, code: code, serverURL: nil,
            individualId: nil, authToken: nil, individualName: nil,
            timestamp: Date()
        )
        guard let data = try? JSONEncoder().encode(message),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return }

        session?.sendMessage(dict, replyHandler: nil, errorHandler: nil)
    }

    func sendAck() {
        let message = ProvisioningMessage(
            type: .ack, code: nil, serverURL: nil,
            individualId: nil, authToken: nil, individualName: nil,
            timestamp: Date()
        )
        guard let data = try? JSONEncoder().encode(message),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return }

        session?.sendMessage(dict, replyHandler: nil, errorHandler: nil)
    }
}

extension WatchConnectivityHandler: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {}

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: message),
              let msg = try? JSONDecoder().decode(ProvisioningMessage.self, from: data)
        else { return }

        switch msg.type {
        case .initiate:
            DispatchQueue.main.async { self.onProvisioningInitiated?(msg) }
        case .codeVerified:
            // Store config in Keychain, then ACK
            if let url = msg.serverURL, let id = msg.individualId, let token = msg.authToken {
                do {
                    let keychain = KeychainManager()
                    try keychain.saveServerURL(url)
                    try keychain.saveIndividualId(id)
                    try keychain.saveAuthToken(token)
                    UserDefaults.standard.set(true, forKey: "isProvisioned")
                    sendAck()
                    DispatchQueue.main.async { self.onConfigReceived?(msg) }
                } catch {
                    // Handle Keychain save failure
                }
            }
        case .codeFailed:
            DispatchQueue.main.async { self.onCodeFailed?() }
        default:
            break
        }
    }
}
```

### 6.3 Message Reliability

`WCSession.sendMessage` requires the counterpart app to be reachable. If delivery fails, implement a fallback to `transferUserInfo`, which queues the message for delivery when the counterpart becomes available. For the provisioning flow, however, real-time messaging is required — if the watch is not reachable, block the flow and show an error rather than silently queuing.

---

## 7. HealthKit Integration

### 7.1 Authorization

```swift
// HealthWatchWatch/Services/HealthKitCollector.swift

import HealthKit

final class HealthKitCollector {
    static let shared = HealthKitCollector()
    private let store = HKHealthStore()

    // All types we want to read
    static let readTypes: Set<HKObjectType> = {
        var types = Set<HKObjectType>()
        let quantityTypes: [HKQuantityTypeIdentifier] = [
            .heartRate, .restingHeartRate,
            .heartRateVariabilitySDNN, .oxygenSaturation,
            .stepCount, .activeEnergyBurned,
            .respiratoryRate, .walkingHeartRateAverage
        ]
        for id in quantityTypes {
            if let t = HKQuantityType.quantityType(forIdentifier: id) { types.insert(t) }
        }
        if let sleep = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) {
            types.insert(sleep)
        }
        return types
    }()

    func requestAuthorization() async throws {
        try await store.requestAuthorization(toShare: [], read: Self.readTypes)
    }

    func authorizationStatus(for type: HKObjectType) -> HKAuthorizationStatus {
        store.authorizationStatus(for: type)
    }

    func deniedTypes() -> [HKObjectType] {
        Self.readTypes.filter { authorizationStatus(for: $0) == .sharingDenied }
    }
}
```

### 7.2 Observer Queries for Background Delivery

Register observer queries for each authorized type. When HealthKit delivers new samples in the background, the observer's update handler fires, which triggers an anchored object query to fetch the actual new data.

```swift
// Inside HealthKitCollector

private var observerQueries: [HKObserverQuery] = []
private var anchors: [HKObjectType: HKQueryAnchor] = [:]

func enableBackgroundDelivery() {
    for type in Self.readTypes {
        guard authorizationStatus(for: type) != .sharingDenied else { continue }

        store.enableBackgroundDelivery(for: type, frequency: .immediate) { success, error in
            if let error { print("BG delivery error for \(type): \(error)") }
        }

        let query = HKObserverQuery(sampleType: type as! HKSampleType, predicate: nil) {
            [weak self] _, completionHandler, error in
            guard error == nil else {
                completionHandler()
                return
            }
            Task {
                await self?.fetchNewSamples(for: type as! HKSampleType)
                completionHandler()
            }
        }
        store.execute(query)
        observerQueries.append(query)
    }
}
```

### 7.3 Anchored Object Queries

```swift
// Inside HealthKitCollector

func fetchNewSamples(for sampleType: HKSampleType) async -> [HealthSample] {
    let anchor = anchors[sampleType]

    return await withCheckedContinuation { continuation in
        let query = HKAnchoredObjectQuery(
            type: sampleType,
            predicate: nil,
            anchor: anchor,
            limit: HKObjectQueryNoLimit
        ) { [weak self] _, newSamples, _, newAnchor, error in
            guard let newSamples, error == nil else {
                continuation.resume(returning: [])
                return
            }

            if let newAnchor {
                self?.anchors[sampleType] = newAnchor
                self?.persistAnchors()
            }

            let healthSamples = newSamples.compactMap { sample -> HealthSample? in
                self?.convertToHealthSample(sample)
            }

            continuation.resume(returning: healthSamples)
        }
        store.execute(query)
    }
}

private func convertToHealthSample(_ sample: HKSample) -> HealthSample? {
    let id = sample.uuid
    let source = sample.sourceRevision.source.bundleIdentifier

    if let quantitySample = sample as? HKQuantitySample {
        let (value, unit) = extractQuantity(quantitySample)
        return HealthSample(
            id: id, typeIdentifier: quantitySample.quantityType.identifier,
            value: value, unit: unit,
            startDate: sample.startDate, endDate: sample.endDate,
            sourceBundleId: source
        )
    }

    if let categorySample = sample as? HKCategorySample {
        return HealthSample(
            id: id, typeIdentifier: categorySample.categoryType.identifier,
            value: Double(categorySample.value), unit: "category",
            startDate: sample.startDate, endDate: sample.endDate,
            sourceBundleId: source
        )
    }

    return nil
}
```

### 7.4 De-duplication

Before buffering, check sample UUIDs against a set of recently transmitted IDs stored in UserDefaults (capped at 10,000 entries, rolling). This prevents duplicate samples from being sent when observer and anchored queries overlap.

---

## 8. Background Execution & Scheduling

### 8.1 Background Refresh Task Scheduling

```swift
// HealthWatchWatch/Services/BackgroundTaskScheduler.swift

import WatchKit

final class BackgroundTaskScheduler {
    static let shared = BackgroundTaskScheduler()

    private let preferredInterval: TimeInterval = 15 * 60  // 15 minutes

    func scheduleNextRefresh() {
        let targetDate = Date().addingTimeInterval(preferredInterval)
        WKApplication.shared().scheduleBackgroundRefresh(
            withPreferredDate: targetDate,
            userInfo: nil
        ) { error in
            if let error {
                print("Failed to schedule BG refresh: \(error.localizedDescription)")
            }
        }
    }
}
```

### 8.2 Budget Management

watchOS allocates a limited number of background refresh opportunities per hour. To stay within budget:

- Complete all work (HealthKit fetch + network push + Core Data save) within 15 seconds.
- Use `URLSession` background transfers for large payloads so the network call doesn't count against the task's execution time.
- Avoid scheduling more frequently than every 15 minutes.
- Test on real hardware over 24+ hour periods to validate the system isn't being throttled.

### 8.3 Background URLSession

```swift
// HealthWatchWatch/Services/DataPushService.swift

import Foundation

final class DataPushService {
    static let shared = DataPushService()

    private lazy var backgroundSession: URLSession = {
        let config = URLSessionConfiguration.background(withIdentifier: "com.company.healthwatch.push")
        config.isDiscretionary = false
        config.sessionSendsLaunchEvents = true
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()

    func collectAndPush() async {
        // 1. Fetch new samples from HealthKit
        let newSamples = await HealthKitCollector.shared.fetchAllNewSamples()

        // 2. Load buffered samples from Core Data
        let buffered = LocalBufferManager.shared.loadBuffered()

        // 3. Combine and de-duplicate
        let allSamples = dedup(newSamples + buffered)

        guard !allSamples.isEmpty else { return }

        // 4. Build payload
        let config = try? KeychainManager().loadProvisioningConfig()
        guard let config else { return }

        let payload = HealthPayload(
            individualId: config.individualId,
            deviceId: WKInterfaceDevice.current().identifierForVendor?.uuidString ?? "unknown",
            timestamp: Date(),
            samples: allSamples,
            batchId: UUID()
        )

        // 5. Serialize and push
        guard let body = try? JSONEncoder.healthWatch.encode(payload),
              let url = URL(string: "\(config.serverURL)/api/v1/health-data")
        else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(config.authToken)", forHTTPHeaderField: "Authorization")

        // Write body to temp file for background upload
        let tempFile = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".json")
        try? body.write(to: tempFile)

        let task = backgroundSession.uploadTask(with: request, fromFile: tempFile)
        task.resume()

        // 6. Buffer samples locally in case push fails
        LocalBufferManager.shared.buffer(allSamples, batchId: payload.batchId)
    }
}

extension DataPushService: URLSessionDataDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let http = task.response as? HTTPURLResponse, (200...299).contains(http.statusCode) {
            // Success — clear buffered data for this batch
            // Extract batch ID from task description or stored reference
            LocalBufferManager.shared.clearBatch(/* batchId */)
        } else if let http = task.response as? HTTPURLResponse, http.statusCode == 401 {
            // Token revoked — enter error state
            DispatchQueue.main.async {
                WatchAppState.shared.mode = .error(.tokenRevoked)
            }
        }
        // On failure, data stays buffered for next cycle
    }
}
```

---

## 9. Local Data Buffering (watchOS)

### 9.1 Core Data Model

```
Entity: BufferedHealthSample
Attributes:
  - id: UUID (indexed)
  - batchId: UUID (indexed)
  - typeIdentifier: String
  - value: Double
  - unit: String
  - startDate: Date
  - endDate: Date
  - sourceBundleId: String
  - bufferedAt: Date (indexed, for 7-day purge)
  - transmitted: Boolean (default false)
```

### 9.2 Buffer Manager

```swift
// HealthWatchWatch/Services/LocalBufferManager.swift

import CoreData

final class LocalBufferManager {
    static let shared = LocalBufferManager()
    private let stack = CoreDataStack.shared

    func buffer(_ samples: [HealthSample], batchId: UUID) {
        let context = stack.backgroundContext()
        context.performAndWait {
            for sample in samples {
                let entity = BufferedHealthSample(context: context)
                entity.id = sample.id
                entity.batchId = batchId
                entity.typeIdentifier = sample.typeIdentifier
                entity.value = sample.value
                entity.unit = sample.unit
                entity.startDate = sample.startDate
                entity.endDate = sample.endDate
                entity.sourceBundleId = sample.sourceBundleId
                entity.bufferedAt = Date()
                entity.transmitted = false
            }
            try? context.save()
        }
    }

    func loadBuffered() -> [HealthSample] {
        let context = stack.viewContext
        let request: NSFetchRequest<BufferedHealthSample> = BufferedHealthSample.fetchRequest()
        request.predicate = NSPredicate(format: "transmitted == false")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \BufferedHealthSample.bufferedAt, ascending: true)]
        request.fetchLimit = 500 // Cap per cycle

        guard let results = try? context.fetch(request) else { return [] }
        return results.map { /* convert to HealthSample */ }
    }

    func clearBatch(_ batchId: UUID) {
        let context = stack.backgroundContext()
        context.performAndWait {
            let request: NSFetchRequest<BufferedHealthSample> = BufferedHealthSample.fetchRequest()
            request.predicate = NSPredicate(format: "batchId == %@", batchId as CVarArg)
            if let results = try? context.fetch(request) {
                results.forEach { context.delete($0) }
                try? context.save()
            }
        }
    }

    func purgeExpired() {
        let context = stack.backgroundContext()
        let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        context.performAndWait {
            let request: NSFetchRequest<BufferedHealthSample> = BufferedHealthSample.fetchRequest()
            request.predicate = NSPredicate(format: "bufferedAt < %@", cutoff as CVarArg)
            if let results = try? context.fetch(request) {
                results.forEach { context.delete($0) }
                try? context.save()
            }
        }
    }

    func clearAllBufferedData() {
        // Called during re-provisioning
        let context = stack.backgroundContext()
        context.performAndWait {
            let request = NSFetchRequest<NSFetchRequestResult>(entityName: "BufferedHealthSample")
            let batchDelete = NSBatchDeleteRequest(fetchRequest: request)
            try? context.execute(batchDelete)
            try? context.save()
        }
    }
}
```

---

## 10. Networking Layer

### 10.1 Endpoint Definitions

```swift
// HealthWatchShared/Networking/Endpoint.swift

import Foundation

struct Endpoint {
    let path: String
    let method: HTTPMethod
    let body: Encodable?
    let queryItems: [URLQueryItem]?

    enum HTTPMethod: String { case GET, POST, PUT, DELETE }

    func urlRequest(baseURL: URL) throws -> URLRequest {
        var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        components.queryItems = queryItems
        var request = URLRequest(url: components.url!)
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let body {
            request.httpBody = try JSONEncoder.healthWatch.encode(body)
        }
        return request
    }

    // iOS endpoints (demo: no login/logout endpoints needed)
    static func getIndividuals() -> Endpoint {
        Endpoint(path: "/api/v1/individuals", method: .GET, body: nil, queryItems: nil)
    }
    static func getHealth(individualId: String, from: Date, to: Date, metric: String?) -> Endpoint { /* ... */ }
    static func provisionWatch(individualId: String) -> Endpoint { /* ... */ }
    static func getAlerts() -> Endpoint { /* ... */ }

    // Watch endpoints
    static func pushHealthData(_ payload: HealthPayload) -> Endpoint {
        Endpoint(path: "/api/v1/health-data", method: .POST, body: payload, queryItems: nil)
    }
    static func heartbeat(individualId: String, deviceId: String) -> Endpoint { /* ... */ }
}
```

### 10.2 Retry Strategy with Exponential Backoff

```swift
// HealthWatchShared/Networking/RetryPolicy.swift

struct RetryPolicy {
    let maxRetries: Int
    let baseDelay: TimeInterval
    let maxDelay: TimeInterval

    static let `default` = RetryPolicy(maxRetries: 5, baseDelay: 2.0, maxDelay: 300.0)

    func delay(for attempt: Int) -> TimeInterval {
        let exponential = baseDelay * pow(2.0, Double(attempt))
        let jitter = Double.random(in: 0...(exponential * 0.1))
        return min(exponential + jitter, maxDelay)
    }
}
```

### 10.3 Certificate Pinning

```swift
// HealthWatchShared/Networking/PinningDelegate.swift

import Foundation

final class CertificatePinningDelegate: NSObject, URLSessionDelegate {
    private let pinnedHashes: Set<String> // SHA-256 hashes of server certificate public keys

    init(pinnedHashes: Set<String>) {
        self.pinnedHashes = pinnedHashes
    }

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let serverTrust = challenge.protectionSpace.serverTrust,
              evaluateTrust(serverTrust)
        else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }
        completionHandler(.useCredential, URLCredential(trust: serverTrust))
    }

    private func evaluateTrust(_ trust: SecTrust) -> Bool {
        // Extract public key hash and compare against pinnedHashes
        // Implementation depends on certificate format
        return true // Placeholder
    }
}
```

---

## 11. Security Implementation

### 11.1 Token Lifecycle (Demo)

| Token | Source | Stored On | Notes |
|---|---|---|---|
| iOS API token | `DemoConfiguration.apiToken` (hardcoded) | In-memory only | Demo server must accept this static token |
| Watch auth token | `DemoConfiguration.watchAuthToken` (hardcoded) | watchOS Keychain (via provisioning) | Sent to watch during provisioning, persists across restarts |

> **Production note:** In the production build, the iOS API token will be a JWT issued by `POST /api/v1/auth/login` and stored in Keychain. The watch auth token will be issued by `POST /api/v1/individuals/{id}/provision` with a 90-day TTL and server-side rotation.

### 11.2 Provisioning Security Checklist

- [ ] Verification code is generated using `SecRandomCopyBytes`, not `arc4random`.
- [ ] Code lives only in memory; never written to UserDefaults or disk.
- [ ] Code expires after 120 seconds with server-validated timestamp.
- [ ] 3 failed attempts trigger a 5-minute lockout.
- [ ] WatchConnectivity messages are encrypted by the OS (Bluetooth encryption).
- [ ] Watch-scoped token is the only secret persisted on the watch.

### 11.3 Data Protection

```swift
// Ensure Core Data store uses appropriate protection level
let storeDescription = NSPersistentStoreDescription()
storeDescription.setOption(
    FileProtectionType.completeUntilFirstUserAuthentication as NSObject,
    forKey: NSPersistentStoreFileProtectionKey
)
```

### 11.4 Secure Code Generation

```swift
func generateSecureCode() -> String {
    var randomBytes = [UInt8](repeating: 0, count: 2)
    _ = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
    let number = (Int(randomBytes[0]) << 8 | Int(randomBytes[1])) % 10000
    return String(format: "%04d", number)
}
```

---

## 12. Error Handling & Recovery

### 12.1 Error Type Hierarchy

```swift
// HealthWatchShared/Models/APIError.swift

enum APIError: Error, LocalizedError {
    case invalidResponse
    case unauthorized
    case rateLimited(retryAfter: String?)
    case serverError(statusCode: Int)
    case httpError(statusCode: Int, data: Data)
    case networkUnavailable
    case timeout
    case encodingFailed
    case decodingFailed(underlying: Error)
}

enum WatchError: Error {
    case tokenRevoked
    case provisioningRequired
    case healthKitUnavailable
    case storageFull
    case configCorrupted
}

enum ProvisioningError: Error {
    case watchNotReachable
    case codeExpired
    case maxAttemptsExceeded
    case configDeliveryFailed
    case keychainSaveFailed
    case serverUnavailable
}
```

### 12.2 Watch Recovery State Machine

```
[Normal Operation]
    │
    ├── Network failure → [Buffering Mode] → retry next cycle → [Normal Operation]
    │
    ├── 401 Unauthorized → [Token Revoked State]
    │       └── Display "Re-provisioning Required"
    │       └── Only exit via new provisioning flow
    │
    ├── Storage full → [Purge Oldest] → log warning → [Normal Operation]
    │
    ├── App terminated → [Cold Start Recovery]
    │       └── Load config from Keychain
    │       └── Load anchors from UserDefaults
    │       └── Resume from last known state
    │
    └── Re-provisioning triggered → [Clear Buffer] → [Store New Config] → [Normal Operation]
```

### 12.3 iOS Error Presentation

Use a centralized error handler that maps `APIError` to user-facing messages. Never show raw error codes or technical details. Provisioning errors should include actionable steps ("Make sure the Apple Watch is nearby and unlocked, then try again").

---

## 13. Testing Strategy

### 13.1 Unit Tests

| Module | Key Test Cases |
|---|---|
| `ProvisioningViewModel` | Code generation randomness, code expiry at 120s, lockout after 3 failures, state transitions |
| `HealthKitCollector` | Sample conversion for each HK type, de-duplication logic, anchor persistence |
| `LocalBufferManager` | Buffer/retrieve/clear cycles, 7-day purge, re-provisioning wipe |
| `APIClient` | 401 handling, retry backoff timing, JSON encoding/decoding |
| `KeychainManager` | Save/load/delete cycles, concurrent access, missing key handling |
| `DataPushService` | Payload construction, batch ID propagation, empty sample handling |

### 13.2 Integration Tests

| Test Scenario | Approach |
|---|---|
| Full provisioning flow | Use paired iPhone + Watch hardware. Verify code display, entry, verification, config storage, and ACK. |
| End-to-end data push | Provision a watch, generate HealthKit samples (via a workout), verify data arrives at a test server. |
| Buffering under network loss | Enable airplane mode on watch, generate samples, disable airplane mode, verify buffered data transmits. |
| 401 recovery | Revoke the watch token server-side, verify watch enters error state on next push. |
| Re-provisioning | Provision for Individual A, buffer data, re-provision for Individual B, verify A's data is discarded. |

### 13.3 UI Tests

- **iOS:** Dashboard rendering with mock data, pull-to-refresh, individual detail chart interaction, provisioning wizard step navigation.
- **watchOS:** Code entry input, status view rendering in both provisioned and unprovisioned states.

### 13.4 Performance Tests

- Measure background task completion time (must be < 15 seconds).
- Measure Core Data fetch time for 500 buffered samples.
- Measure payload serialization time for 500 samples.
- iOS dashboard launch-to-content time with 200 individuals.

---

## 14. CI/CD & Build Configuration

### 14.1 Build Schemes

| Scheme | Configuration | Server URL | Notes |
|---|---|---|---|
| HealthWatch-Demo | Debug | https://dev-api.healthwatch.example | Hardcoded identity, mock data fallback, verbose logging |
| HealthWatch-Staging | Release | https://staging-api.healthwatch.example | TestFlight distribution |
| HealthWatch-Production | Release | https://api.healthwatch.example | App Store release (requires auth implementation) |

### 14.2 Build Pipeline

```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│   PR Build   │───▶│  Unit Tests  │───▶│  SwiftLint   │───▶│  Build Both  │
│  (trigger)   │    │  (iOS+Watch) │    │  (warnings)  │    │   Targets    │
└─────────────┘    └─────────────┘    └─────────────┘    └──────┬──────┘
                                                                │
                                              ┌─────────────────┴────────┐
                                              │  Merge to main           │
                                              ├──────────────────────────┤
                                              │  Fastlane: build + sign  │
                                              │  Upload to TestFlight    │
                                              │  Notify QA via Slack     │
                                              └──────────────────────────┘
```

### 14.3 Fastlane Configuration

```ruby
# Fastfile (simplified)
platform :ios do
  lane :demo do
    increment_build_number
    build_app(
      workspace: "HealthWatch.xcworkspace",
      scheme: "HealthWatch-Demo",
      export_method: "development"
    )
  end

  lane :beta do
    increment_build_number
    build_app(
      workspace: "HealthWatch.xcworkspace",
      scheme: "HealthWatch-Staging",
      export_method: "app-store"
    )
    upload_to_testflight
  end
end
```

### 14.4 Code Signing

Use automatic signing with Xcode Managed profiles for development. For CI, use manual signing with match-managed certificates and provisioning profiles stored in a private git repository. Both the iOS and watchOS targets must share the same team and have matching entitlements for Keychain Sharing.

---

## 15. Logging & Observability

### 15.1 Logging Framework

Use Apple's `os.log` / `Logger` API for structured logging. Define subsystems and categories:

```swift
import os

extension Logger {
    static let provisioning = Logger(subsystem: "com.company.healthwatch", category: "provisioning")
    static let healthKit = Logger(subsystem: "com.company.healthwatch", category: "healthkit")
    static let networking = Logger(subsystem: "com.company.healthwatch", category: "networking")
    static let buffer = Logger(subsystem: "com.company.healthwatch", category: "buffer")
    static let sync = Logger(subsystem: "com.company.healthwatch", category: "sync")
}

// Usage
Logger.provisioning.info("Code generated, expires in 120s")
Logger.networking.error("Push failed: \(error.localizedDescription, privacy: .public)")
Logger.healthKit.debug("Fetched \(samples.count) new samples for \(type, privacy: .public)")
```

### 15.2 Watch Heartbeat

The watch sends a `POST /api/v1/device/heartbeat` every push cycle (piggyback on data push or standalone if no data). The heartbeat includes the device ID, battery level, buffer size, and last successful push timestamp. The server uses heartbeats for absence detection — if no heartbeat is received for 1 hour, the server flags the individual's status as "offline" on the staff dashboard.

### 15.3 Server-Side Metrics to Track

| Metric | Purpose |
|---|---|
| Push latency (watch → server) | Detect network or processing delays |
| Batch size distribution | Optimize payload limits |
| Push failure rate by error code | Identify systemic issues |
| Buffer age at delivery | Measure how stale data gets during outages |
| Heartbeat gap duration | Detect prolonged watch disconnections |
| Unique active devices per hour | Monitor fleet health |

---

## 16. App Store & Distribution

### 16.1 App Store Review Considerations

| Requirement | Implementation |
|---|---|
| HealthKit usage description | `NSHealthShareUsageDescription` in watchOS Info.plist — explain that the app reads health metrics for remote care monitoring. |
| Background modes justification | Document that background refresh is for periodic health data transmission and HealthKit background delivery is for timely vitals capture. |
| Privacy nutrition label | Declare: Health data (linked to user identifier), usage data (analytics). |
| Data deletion | Provide a mechanism for individuals/admins to request full data deletion from the server. |

### 16.2 Entitlements Files

**iOS — HealthWatch.entitlements:**
```xml
<key>keychain-access-groups</key>
<array>
    <string>$(TeamIdentifierPrefix)com.company.healthwatch.shared</string>
</array>
<key>aps-environment</key>
<string>production</string>
```

**watchOS — HealthWatchWatch.entitlements:**
```xml
<key>com.apple.developer.healthkit</key>
<true/>
<key>com.apple.developer.healthkit.background-delivery</key>
<true/>
<key>keychain-access-groups</key>
<array>
    <string>$(TeamIdentifierPrefix)com.company.healthwatch.shared</string>
</array>
```

### 16.3 Minimum Deployment & Device Matrix

| Device | Minimum OS | Reason |
|---|---|---|
| iPhone 8+ | iOS 16.0 | SwiftUI Charts (iOS 16), modern WCSession APIs |
| Apple Watch Series 5+ | watchOS 9.0 | Always-on network, reliable background execution budget |

---

## 17. Implementation Phases & Timeline

### Phase 1 — Foundation (Weeks 1–2)

| Week | Deliverable |
|---|---|
| 1 | Xcode project setup, shared package, CI pipeline, code signing, linting |
| 2 | Keychain manager, API client with `StaticTokenStore`, endpoint definitions, error types, `DemoConfiguration`, `MockIndividuals` |

**Exit criteria:** Project builds for both targets. API client can make authenticated requests using the hardcoded demo token. Mock individual data is available.

### Phase 2 — Provisioning (Weeks 3–5)

| Week | Deliverable |
|---|---|
| 3 | WatchConnectivity bridge (iOS + watchOS), message serialization |
| 4 | Provisioning state machine (iOS), code generation, code entry view (watchOS) |
| 5 | End-to-end provisioning: code verification, config delivery (using `DemoConfiguration` values), Keychain persistence, ACK |

**Exit criteria:** Staff can select an individual from the mock list, provision a watch with the demo server URL and token, and the watch stores config and enters provisioned mode.

### Phase 3 — Data Collection (Weeks 6–8)

| Week | Deliverable |
|---|---|
| 6 | HealthKit authorization, observer queries, anchored object queries |
| 7 | Core Data buffer, buffer manager, 7-day purge, de-duplication |
| 8 | Background task scheduler, DataPushService, background URLSession, retry logic |

**Exit criteria:** Provisioned watch autonomously collects HealthKit samples and pushes them to the demo server every 15 minutes with local buffering on failure.

### Phase 4 — Staff Monitoring (Weeks 9–11)

| Week | Deliverable |
|---|---|
| 9 | Dashboard view — individual list with mock data fallback, status indicators, polling |
| 10 | Individual detail view — health metric charts (Swift Charts), time range selector |
| 11 | Alerts configuration, push notifications for threshold breaches |

**Exit criteria:** Staff can view real-time and historical health data for all individuals on their own device. Dashboard pre-populates with mock data and updates from the server when available.

### Phase 5 — Demo Polish & Testing (Weeks 12–14)

| Week | Deliverable |
|---|---|
| 12 | Error recovery flows (401 handling, re-provisioning, cold start recovery) |
| 13 | Accessibility basics (VoiceOver labels, Dynamic Type), dark mode polish |
| 14 | Integration testing on hardware, 24-hour soak test, demo rehearsal |

**Exit criteria:** Complete demo-ready build. All features functional end-to-end on physical hardware. Demo script validated.

---

### Total Estimated Timeline: 14 Weeks

```
Phase 1: Foundation         ██████░░░░░░░░░░  Weeks 1–2
Phase 2: Provisioning       ░░░░████████░░░░  Weeks 3–5
Phase 3: Data Collection    ░░░░░░░░████████  Weeks 6–8
Phase 4: Staff Monitoring   ░░░░░░░░░░██████  Weeks 9–11
Phase 5: Demo Polish        ░░░░░░░░░░░░████  Weeks 12–14
```

---

## Appendix: What Changes for Production

The following items are deferred from the demo build and must be implemented before a production release:

| Area | Demo Approach | Production Requirement |
|---|---|---|
| Authentication | `DemoConfiguration` hardcoded identity | OAuth 2.0 / JWT login flow with `AuthManager` |
| Login UI | Skipped entirely | `LoginView` + `LoginViewModel` with credential entry |
| Session cleanup | Not needed (no session) | `SessionManager.cleanEverything()` on logout — aggressive Keychain, cookie, cache, and state cleanup |
| Token issuance | `DemoConfiguration.apiToken` static string | `POST /api/v1/auth/login` returns JWT; `POST /api/v1/individuals/{id}/provision` returns watch-scoped token |
| Token rotation | Not implemented | Server returns refreshed token in response headers; watch updates Keychain |
| Token TTL | Infinite (static) | Staff JWT: 8 hours with refresh; Watch token: 90 days with server-side rotation |
| Individual list | `MockIndividuals.all` fallback | Server-only via `GET /api/v1/individuals` with staff-scoped access control |
| Provisioning token | `DemoConfiguration.watchAuthToken` static string | Dynamically issued per-individual from the server |
| Certificate pinning | Placeholder implementation | Real SHA-256 pin set for production server certificate |
| App Store submission | Development distribution only | Full App Store review with privacy nutrition labels and HealthKit justification |

---

*Confidential — HealthWatch Implementation Guide (Demo Build) v1.0 — April 2026*
