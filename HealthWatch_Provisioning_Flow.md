# HealthWatch — Provisioning Flow

## Overview

Provisioning is the process of securely linking an Apple Watch to a specific individual's health record. The flow uses a **device code** (8-character hex) displayed on the Watch, which is either **scanned via QR code** or **entered manually** on the iOS app. The iOS app registers the device-to-individual mapping with the server, and the Watch **polls the server** until its configuration is available. Once provisioned, the Watch begins collecting HealthKit data and pushing it to the backend under that individual's identity.

**Key design decision:** Provisioning does **not** depend on WCSession. Any iPhone with the app can provision any Watch — the devices do not need to be paired. WCSession is only used for the optional deprovision signal.

---

## Actors

| Actor | Role |
|---|---|
| **Clinician / Caregiver** | Uses the iOS app to select an individual and enter/scan the device code |
| **Watch Wearer** | Taps "Provision" on the Watch to display the device code |
| **iOS App** | Scans the QR code or accepts manual code entry, registers the mapping with the server |
| **watchOS App** | Generates device code, displays it, polls server for config, stores config in Keychain |
| **Backend Server** | Stores the device-to-individual mapping and serves provisioning config |

---

## Step-by-Step Flow

### 1. Watch: Generate Device Code

When unprovisioned, the Watch shows `WatchUnprovisionedView` with a "Provision" button. On tap:

```
WatchUnprovisionedView → WatchAppState.beginProvisioning()
```

- `WatchAppState` generates an 8-character hex code via `getOrCreateDeviceCode()`
- The code is persisted to `UserDefaults` so it survives app restarts
- Mode transitions to `.showingCode(deviceCode:)`

### 2. Watch: Display Code & Begin Polling

`WatchProvisionCodeView` displays the code formatted as `XXXX-XXXX` and starts `DeviceConfigPoller`:

- Polls `GET /api/v1/device/{deviceCode}/config` every 5 seconds
- On `status == "provisioned"` → returns config
- On 404 or `status == "pending"` → continues polling
- Timeout after 5 minutes (`AppConstants.qrProvisioningTimeout`)
- A "Cancel" button stops polling and returns to `.unprovisioned`

### 3. iOS: Select Individual

The clinician opens the **Provisioning** tab and selects an individual from the list.

### 4. iOS: Scan QR Code or Enter Code Manually

Two options are presented:

**Option A — Scan QR Code (primary):**
- `QRScannerView` opens the camera via `AVCaptureSession` + `AVCaptureMetadataOutput`
- Scans for a QR code containing JSON: `{"app": "healthwatch", "version": 1, "deviceId": "..."}`
- Validates the payload and extracts the `deviceId`

**Option B — Enter Code Manually (fallback):**
- Text field accepts the 8-character hex code (with or without dash)
- Validates: exactly 8 hex characters after stripping dashes/spaces

### 5. iOS: Register Device with Server

```
ProvisioningViewModel.registerDevice(deviceCode:)
→ POST /api/v1/device/register { deviceId, individualId }
→ Response: { success, deviceId, individualId }
```

On success (or demo fallback), the iOS app stores the mapping locally:
- `provisionedIndividualId` → UserDefaults
- `provisionedIndividualName` → UserDefaults
- `provisionedDeviceCode` → UserDefaults

The iOS provisioning flow is now complete (state → `.success`).

### 6. Watch: Receive Config from Server

The `DeviceConfigPoller` detects that the server now returns `status == "provisioned"`:

```json
{
    "status": "provisioned",
    "serverURL": "https://...",
    "individualId": "ind-001",
    "individualName": "Alice Johnson",
    "authToken": "watch-token-..."
}
```

### 7. Watch: Store Config & Transition

`WatchAppState.completeProvisioning(with:)` is called:

1. Stores `serverURL`, `individualId`, and `authToken` in Keychain (`kSecAttrAccessibleAfterFirstUnlock`)
2. Stores `individualName` in UserDefaults
3. Mode transitions to `.provisioned`
4. `startDataCollection()` begins:
   - Requests HealthKit authorization
   - Restores anchored query positions
   - Enables background delivery for all health types
   - Schedules background refresh tasks (every 15 minutes)

---

## Sequence Diagram

```
  iOS App                     Server                    watchOS App
  ────────                    ──────                    ───────────
     │                           │                           │
     │                           │              User taps "Provision"
     │                           │              Generate device code
     │                           │              Display code: "A1B2-C3D4"
     │                           │                           │
     │                           │         GET /device/{id}/config (poll)
     │                           │<──────────────────────────│
     │                           │──── 404 (pending) ───────>│
     │                           │           ... (every 5s) ...
     │                           │                           │
     │  User selects individual  │                           │
     │  Scans QR / enters code   │                           │
     │                           │                           │
     │  POST /device/register    │                           │
     │  { deviceId, individualId }                           │
     │──────────────────────────>│                           │
     │<──── { success: true } ───│                           │
     │                           │                           │
     │  Show success             │         GET /device/{id}/config (poll)
     │                           │<──────────────────────────│
     │                           │── 200 { provisioned, config } ──>│
     │                           │                           │
     │                           │              Store config in Keychain
     │                           │              Start HealthKit collection
```

---

## Message Types (WCSession — deprovision only)

| Type | Direction | Purpose |
|---|---|---|
| `.deprovision` | iOS → Watch | Tell Watch to clear config and return to unprovisioned |
| `.ack` | Watch → iOS | Acknowledge deprovision was processed |

---

## Deprovisioning

To remove provisioning from the iOS app:

1. `ProvisioningViewModel.removeProvisioning()`:
   - Calls `DELETE /api/v1/device/{deviceCode}` to remove server mapping
   - Sends `.deprovision` message via WCSession (if Watch is reachable)
   - Clears local UserDefaults (individualId, name, deviceCode)

2. Watch receives `.deprovision` via `WatchConnectivityHandler`:
   - Calls `WatchAppState.resetToUnprovisioned()`
   - Stops all HealthKit observer queries
   - Clears CoreData buffer, deduplication cache, Keychain, UserDefaults
   - Transitions mode to `.unprovisioned`

---

## API Endpoints

| Endpoint | Method | Auth | Caller | Purpose |
|---|---|---|---|---|
| `POST /api/v1/device/register` | POST | Bearer (staff token) | iOS | Map device ID to individual |
| `GET /api/v1/device/{deviceId}/config` | GET | None | Watch | Poll for provisioning config |
| `DELETE /api/v1/device/{deviceId}` | DELETE | Bearer (staff token) | iOS | Remove device mapping |

---

## Security Measures

| Measure | Detail |
|---|---|
| **Device code** | 8-character hex (32 bits of entropy) generated via random bytes |
| **Code persistence** | Stored in UserDefaults on Watch; not transmitted over WCSession |
| **Polling timeout** | 5 minutes — prevents indefinite server load |
| **Secure storage** | Keychain with `kSecAttrAccessibleAfterFirstUnlock` |
| **Transport** | HTTPS for all server communication |
| **Token isolation** | Watch receives a dedicated auth token, separate from the iOS staff token |
| **Server-side mapping** | Device-to-individual association lives on the server, not on the devices |

---

## Constants

| Constant | Value | Source |
|---|---|---|
| `qrPollingInterval` | 5 seconds | `AppConstants.swift` |
| `qrProvisioningTimeout` | 300 seconds (5 min) | `AppConstants.swift` |

---

## Key Files

### iOS

| File | Role |
|---|---|
| `Features/Provisioning/ProvisioningView.swift` | Main provisioning UI — individual selection, scanner, code entry |
| `Features/Provisioning/ProvisioningViewModel.swift` | State machine, device registration, deprovisioning |
| `Features/Provisioning/QRScannerView.swift` | AVFoundation camera QR scanner |
| `Features/Provisioning/ProvisioningStatusView.swift` | Reusable status/progress component |
| `Services/WatchConnectivityManager.swift` | WCSession delegate (deprovision messages only) |
| `Shared/Networking/Endpoint.swift` | API endpoint definitions including QR provisioning |

### watchOS

| File | Role |
|---|---|
| `Features/Provisioning/WatchUnprovisionedView.swift` | "Provision" button when unprovisioned |
| `Features/Provisioning/WatchQRProvisionView.swift` | Device code display + polling indicator |
| `Features/Provisioning/WatchErrorView.swift` | Error display with recovery guidance |
| `Services/DeviceConfigPoller.swift` | Server polling service for provisioning config |
| `Services/WatchConnectivityHandler.swift` | WCSession delegate (deprovision handling only) |
| `Services/WatchAppState.swift` | State machine driving UI transitions |

### Shared

| File | Role |
|---|---|
| `Shared/Models/ProvisioningMessage.swift` | Message model — `.ack` and `.deprovision` types |
| `Shared/Security/KeychainManager.swift` | Keychain read/write for provisioning config |
| `Shared/Constants/AppConstants.swift` | Polling interval, timeout values |

---

## Error Recovery

| Error | Behavior |
|---|---|
| Server unreachable during polling | Watch retries every 5 seconds until timeout |
| Polling timeout (5 min) | Watch shows timeout error, user can retry |
| Cancel during polling | Watch returns to unprovisioned state |
| Invalid QR code | iOS shows error, user can retry scan or enter manually |
| Invalid manual code | iOS shows validation error |
| Registration fails (server) | Demo fallback simulates success |
| Keychain save fails | Watch transitions to `.error(.keychainFailed)` |
| Token revoked (HTTP 401) | Watch calls `recoverFromTokenRevoked()` → full re-provisioning |
| HealthKit denied | Watch shows `.error(.healthKitUnavailable)` |
