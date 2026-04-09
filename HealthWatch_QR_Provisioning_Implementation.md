# HealthWatch — QR Code Provisioning Implementation Guide

## Overview

This document describes how to implement the QR code provisioning flow described in `HealthWatch_QR_Provisioning_Spec.md`. The implementation replaces the current 4-digit code + WCSession provisioning with a QR code + server-polling approach.

---

## Phase 1: New Files to Create

### 1.1 Watch — QR Code Display View

**File:** `HealthWatchApp Watch App/Features/Provisioning/WatchQRProvisionView.swift`

**Purpose:** Replaces `AwaitingSetupView` and `WatchCodeEntryView`. Shows a "Provision" button when unprovisioned. On tap, generates and displays a QR code containing the device ID, and begins server polling.

**Key components:**
- Generate device ID from `WKInterfaceDevice.current().identifierForVendor`
- Create QR code using `CoreImage.CIFilter(name: "CIQRCodeGenerator")`
- Display the QR code image scaled for the watch screen
- Show a "Cancel" button to return to unprovisioned state
- Display polling status ("Waiting for pairing...")

**Dependencies:** `CoreImage`, `WatchKit`

### 1.2 Watch — Device Config Polling Service

**File:** `HealthWatchApp Watch App/Services/DeviceConfigPoller.swift`

**Purpose:** Polls the server every 5 seconds with the device ID to check if provisioning config is available.

**Key components:**
```
class DeviceConfigPoller {
    func startPolling(deviceId: String) async -> ProvisioningConfig?
    func stopPolling()
}

struct ProvisioningConfig: Codable {
    let status: String        // "provisioned" or "pending"
    let serverURL: String?
    let individualId: String?
    let individualName: String?
    let authToken: String?
}
```

**Behavior:**
- Poll `GET /api/v1/device/{deviceId}/config` every 5 seconds
- On HTTP 200 with `status == "provisioned"` → return config
- On HTTP 404 or `status == "pending"` → continue polling
- Timeout after 5 minutes (`AppConstants.qrProvisioningTimeout`)
- Cancel on user request

### 1.3 iOS — QR Code Scanner View

**File:** `HealthWatch/Features/Provisioning/QRScannerView.swift`

**Purpose:** Camera view that scans QR codes. Uses `AVFoundation` (`AVCaptureSession` + `AVCaptureMetadataOutput`) wrapped in a `UIViewControllerRepresentable`.

**Key components:**
- `QRScannerViewController` — UIKit controller with camera + metadata detection
- `QRScannerView` — SwiftUI wrapper using `UIViewControllerRepresentable`
- Callback: `onCodeScanned: (String) -> Void`
- Validates QR payload has `"app": "healthwatch"` and `"version": 1`
- Extracts `deviceId` from JSON payload
- Requires `NSCameraUsageDescription` in `Info.plist`

### 1.4 iOS — Device Registration Request Model

**File:** No new file needed — add to existing `Endpoint.swift`

**New endpoint:**
```swift
static func registerDevice(deviceId: String, individualId: String) -> Endpoint {
    Endpoint(
        path: "/api/v1/device/register",
        method: .POST,
        body: DeviceRegistration(deviceId: deviceId, individualId: individualId)
    )
}

static func removeDevice(deviceId: String) -> Endpoint {
    Endpoint(path: "/api/v1/device/\(deviceId)", method: .DELETE)
}
```

**New model (in Endpoint.swift or separate file):**
```swift
struct DeviceRegistration: Codable, Sendable {
    let deviceId: String
    let individualId: String
}
```

---

## Phase 2: Files to Modify

### 2.1 ProvisioningMessage.swift (both targets)

**Change:** Add QR-related message types (optional — only if keeping WCSession for deprovision).

No change needed for the core provisioning flow since it no longer uses WCSession. The existing `.deprovision` type can remain for the optional WCSession deprovision path.

### 2.2 ProvisioningView.swift (iOS)

**Current:** Individual selection → code display → watch code entry → verification → success
**New:** Individual selection → QR scanner → register with server → success

**Changes:**
- Remove states: `checkingWatchConnection`, `watchNotReachable`, `displayingCode`, `waitingForCodeEntry`, `verifyingCode`, `codeAccepted`, `codeFailed`, `sendingConfig`, `locked`
- Add states: `scanningQR`, `registeringDevice`, `registrationSuccess`, `registrationFailed`
- Replace `CodeDisplayView` usage with `QRScannerView`
- After successful scan, call `POST /api/v1/device/register`
- Remove WCSession reachability checks

### 2.3 ProvisioningViewModel.swift (iOS)

**Changes:**
- Remove: `generateCode()`, `verifyCode()`, `handleCodeFromWatch()`, `sendConfiguration()`, code expiry logic, failed attempts tracking, lockout logic
- Add: `handleScannedQR(payload:)` — parse QR JSON, extract device ID
- Add: `registerDevice(deviceId:)` — call server endpoint to map individual ↔ device
- Simplify state machine to: `selectIndividual` → `scanningQR` → `registeringDevice` → `success` / `error`
- Keep: `removeProvisioning()` (now also calls `DELETE /api/v1/device/{deviceId}`)
- Keep: `provisionedIndividualId` tracking in UserDefaults

### 2.4 ProvisioningState enum (iOS)

**New simplified states:**
```swift
enum ProvisioningState: Equatable {
    case selectIndividual
    case scanningQR
    case registeringDevice
    case success
    case error(String)
}
```

### 2.5 WatchAppState.swift (watchOS)

**Changes:**
- Add new mode: `.showingQR(deviceId: String)` — between unprovisioned and provisioned
- Add: `beginQRProvisioning()` — generates device ID, transitions to `.showingQR`
- Modify: `completeProvisioning()` — now called when poller returns config
- Keep: `resetToUnprovisioned()` unchanged

**Updated mode enum:**
```swift
enum WatchMode {
    case unprovisioned
    case showingQR(deviceId: String)
    case provisioned
    case error(WatchError)
}
```

### 2.6 HealthWatchAppApp.swift (watchOS)

**Changes:**
- Replace `AwaitingSetupView` with `WatchQRProvisionView` for `.unprovisioned`
- Add case for `.showingQR` mode → show `WatchQRProvisionView` in QR display mode
- Remove: `WatchCodeEntryView` routing
- Remove: WCSession provisioning callback setup (keep deprovision callback)

### 2.7 Endpoint.swift (iOS + watch shared)

**Add:**
- `registerDevice(deviceId:individualId:)` — POST
- `removeDevice(deviceId:)` — DELETE
- `getDeviceConfig(deviceId:)` — GET (for watch polling)

### 2.8 AppConstants.swift (both targets)

**Add:**
```swift
static let qrPollingInterval: TimeInterval = 5
static let qrProvisioningTimeout: TimeInterval = 300  // 5 minutes
```

### 2.9 Info.plist (iOS)

**Add:** `NSCameraUsageDescription` — "HealthWatch needs camera access to scan the provisioning QR code on the Apple Watch."

### 2.10 WatchConnectivityHandler.swift (watchOS)

**Changes:**
- Remove: `onProvisioningInitiated` callback (no longer needed)
- Remove: `onConfigReceived` callback (config comes from server now)
- Remove: `onCodeFailed` callback
- Remove: `.initiate`, `.codeVerified`, `.codeFailed` handlers
- Keep: `.deprovision` handler (for optional WCSession deprovision)
- Keep: `sendAck()` (for deprovision ACK)

### 2.11 WatchConnectivityManager.swift (iOS)

**Changes:**
- Remove: `onCodeReceived` callback (no more code exchange)
- Keep: `onAckReceived` (for deprovision ACK)
- Keep: `send()` for deprovision messages

---

## Phase 3: Files to Remove / Deprecate

| File | Action | Reason |
|---|---|---|
| `HealthWatch/Features/Provisioning/CodeDisplayView.swift` | **Remove** | No longer displaying 4-digit codes |
| `HealthWatchApp Watch App/Features/Provisioning/WatchCodeEntryView.swift` | **Remove** | No longer entering codes on watch |
| `HealthWatchApp Watch App/Features/Provisioning/AwaitingSetupView.swift` | **Remove** | Replaced by `WatchQRProvisionView` |

---

## Phase 4: Implementation Order

### Step 1: Shared Foundation
1. Add new constants to `AppConstants.swift` (both targets)
2. Add new endpoints to `Endpoint.swift`
3. Create `ProvisioningConfig` model (for watch polling response)
4. Add `NSCameraUsageDescription` to `Info.plist`

### Step 2: Watch Side
1. Create `DeviceConfigPoller.swift`
2. Create `WatchQRProvisionView.swift`
3. Update `WatchMode` enum in `WatchAppState.swift`
4. Update `HealthWatchAppApp.swift` routing
5. Clean up `WatchConnectivityHandler.swift`
6. Remove `AwaitingSetupView.swift` and `WatchCodeEntryView.swift`

### Step 3: iOS Side
1. Create `QRScannerView.swift`
2. Rewrite `ProvisioningViewModel.swift` with new state machine
3. Rewrite `ProvisioningView.swift` with scanner flow
4. Update `WatchConnectivityManager.swift` (remove code callbacks)
5. Remove `CodeDisplayView.swift`

### Step 4: Integration & Cleanup
1. Update `removeProvisioning()` to call `DELETE /api/v1/device/{deviceId}`
2. Update provisioning flow documentation
3. Build both targets
4. Test end-to-end

---

## API Contract Summary

| Endpoint | Method | Auth | Caller | Purpose |
|---|---|---|---|---|
| `POST /api/v1/device/register` | POST | Bearer (staff token) | iOS | Map device ID to individual |
| `GET /api/v1/device/{deviceId}/config` | GET | None | Watch | Poll for provisioning config |
| `DELETE /api/v1/device/{deviceId}` | DELETE | Bearer (staff token) | iOS | Remove device mapping (deprovision) |

### Request/Response Details

**POST /api/v1/device/register**
```
Request:  { "deviceId": "UUID", "individualId": "string" }
Response: { "success": true, "deviceId": "UUID", "individualId": "string" }
Error:    409 { "error": "device_already_provisioned", "currentIndividualId": "string" }
```

**GET /api/v1/device/{deviceId}/config**
```
Pending:     404 { "status": "pending" }
Provisioned: 200 { "status": "provisioned", "serverURL": "string",
                    "individualId": "string", "individualName": "string",
                    "authToken": "string" }
```

**DELETE /api/v1/device/{deviceId}**
```
Response: 200 { "success": true }
```

---

## Demo Mode Considerations

Since the app uses `DemoConfiguration` for hardcoded values, the implementation should include a **mock server mode** for the new endpoints:

- `POST /api/v1/device/register` → always returns success (store mapping locally)
- `GET /api/v1/device/{deviceId}/config` → return provisioned response after `register` was called for that device ID
- `DELETE /api/v1/device/{deviceId}` → always returns success

This can be done with a `MockProvisioningServer` class that the polling service and registration call use when `DemoConfiguration.isDemo` is true, bypassing actual HTTP requests.

---

## Verification Checklist

- [ ] Watch app shows "Provision" button when unprovisioned
- [ ] Tapping "Provision" generates and displays a QR code
- [ ] QR code contains valid JSON with device ID
- [ ] Watch begins polling server after QR is displayed
- [ ] iOS app can scan QR code from camera
- [ ] iOS app extracts device ID from QR payload
- [ ] iOS app successfully registers device with server
- [ ] Watch receives config from poll and transitions to provisioned
- [ ] Watch stores config in Keychain
- [ ] HealthKit collection starts after provisioning
- [ ] Cancel on watch stops polling and returns to unprovisioned
- [ ] Remove provisioning from iOS calls DELETE endpoint
- [ ] Build succeeds for both iOS and watchOS targets
- [ ] Old provisioning files (CodeDisplayView, WatchCodeEntryView, AwaitingSetupView) are removed
- [ ] `Info.plist` has camera usage description
