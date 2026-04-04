# HealthWatch — Provisioning Flow

## Overview

Provisioning is the process of securely linking an Apple Watch to a specific individual's health record. It uses a **4-digit code** exchanged between the iOS app and watchOS app over **WCSession** (Watch Connectivity). Once provisioned, the Watch begins collecting HealthKit data and pushing it to the backend under that individual's identity.

---

## Actors

| Actor | Role |
|---|---|
| **Clinician / Caregiver** | Uses the iOS app to initiate provisioning and select which individual the Watch will monitor |
| **Watch Wearer** | Enters the 4-digit code on the Watch to confirm pairing |
| **iOS App** | Generates the code, verifies it, and sends configuration to the Watch |
| **watchOS App** | Receives the code prompt, collects user input, stores config in Keychain |
| **Backend Server** | (In production) validates the provisioning request and issues an auth token |

---

## Step-by-Step Flow

### 1. Initiation (iOS)

The clinician opens the **Provisioning** tab on the iOS app and selects an individual from the list.

```
ProvisioningView → ProvisioningViewModel.startProvisioning(for: individual)
```

- The view model checks that the Watch is reachable via `WatchConnectivityManager.shared.isReachable`.
- If unreachable, the flow pauses at a "Connecting to Watch..." screen.

### 2. Code Generation (iOS)

Once the Watch is reachable, the iOS app generates a cryptographically secure 4-digit code.

```swift
// ProvisioningViewModel.swift
private func generateCode() -> String {
    var bytes = [UInt8](repeating: 0, count: 4)
    _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
    let digits = bytes.map { String($0 % 10) }
    return digits.joined()
}
```

- The code is stored in `currentCode` along with `codeGeneratedAt = Date()`.
- A **120-second countdown timer** begins on screen (`CodeDisplayView`).
- The code turns red when fewer than 30 seconds remain.

### 3. Initiate Message (iOS → Watch)

The iOS app sends a `.initiate` provisioning message to the Watch.

```swift
// ProvisioningViewModel.swift
let message = ProvisioningMessage(
    type: .initiate,
    individualName: selectedIndividual.name
)
WatchConnectivityManager.shared.send(message)
```

This message travels over `WCSession.sendMessage(_:replyHandler:errorHandler:)`.

### 4. Watch Receives Prompt (watchOS)

The `WatchConnectivityHandler` receives the message and triggers a callback.

```
WatchConnectivityHandler.onProvisioningInitiated → WatchAppState.beginProvisioning(with:)
```

The Watch transitions from `.unprovisioned` to `.provisioning` mode and displays `WatchCodeEntryView`, which shows:
- The individual's name ("Provisioning for Alice Johnson")
- A secure text field for the 4-digit code
- A "Confirm" button (enabled only when 4 digits are entered)

### 5. Code Entry (watchOS)

The Watch wearer types the 4-digit code shown on the iPhone into the Watch's text field and taps **Confirm**.

```swift
// WatchCodeEntryView.swift
WatchConnectivityHandler.shared.sendCodeToiOS(code)
```

This sends a `.codeEntry` message back to the iOS app:

```swift
let message = ProvisioningMessage(type: .codeEntry, code: code)
```

### 6. Code Verification (iOS)

The iOS app receives the code via `WatchConnectivityManager.onCodeReceived` and verifies it.

```swift
// ProvisioningViewModel.swift
func verifyCode(_ receivedCode: String) -> Bool {
    guard let code = currentCode,
          let generated = codeGeneratedAt,
          Date().timeIntervalSince(generated) < AppConstants.provisioningCodeExpiry
    else { return false }
    return receivedCode == code
}
```

**Verification checks:**
1. The code matches the generated code
2. The code has not expired (120-second window)

### 7a. Success Path — Send Configuration (iOS → Watch)

If the code is correct, the iOS app sends a `.codeVerified` message containing the provisioning configuration:

```swift
let message = ProvisioningMessage(
    type: .codeVerified,
    serverURL: DemoConfiguration.serverURL,
    individualId: individual.id,
    authToken: DemoConfiguration.watchAuthToken,
    individualName: individual.name
)
WatchConnectivityManager.shared.send(message)
```

### 7b. Failure Path — Code Rejected (iOS → Watch)

If the code is wrong:
- The attempt counter increments (`failedAttempts += 1`)
- A `.codeFailed` message is sent to the Watch
- The Watch displays an error and allows retry

**After 3 failed attempts**, the flow enters a **5-minute lockout**:
```swift
if failedAttempts >= AppConstants.maxProvisioningAttempts {
    state = .lockedOut
    // Lockout lasts AppConstants.provisioningLockoutDuration (300 seconds)
}
```

### 8. Watch Stores Configuration (watchOS)

On receiving `.codeVerified`, the `WatchConnectivityHandler` stores the configuration securely in Keychain:

```swift
// WatchConnectivityHandler.swift
let keychain = KeychainManager()
try keychain.saveServerURL(serverURL)
try keychain.saveIndividualId(individualId)
try keychain.saveAuthToken(authToken)
```

The Keychain uses `kSecAttrAccessibleAfterFirstUnlock` so credentials survive Watch restarts.

### 9. Acknowledgement (Watch → iOS)

After successfully storing the config, the Watch sends an `.ack` message back to the iOS app:

```swift
WatchConnectivityHandler.shared.sendAck()
// Sends: ProvisioningMessage(type: .ack)
```

### 10. Completion

**On iOS:**
- `WatchConnectivityManager.onAckReceived` fires
- `ProvisioningViewModel` transitions to `.success` state
- Success screen is displayed with a checkmark

**On watchOS:**
- `WatchAppState.completeProvisioning(individualName:)` is called
- Individual name is persisted to `UserDefaults`
- Mode transitions to `.provisioned`
- `startDataCollection()` is called, which:
  - Requests HealthKit authorization
  - Restores anchored query positions
  - Enables background delivery for all health types
  - Schedules background refresh tasks (every 15 minutes)

---

## Sequence Diagram

```
  iOS App                    WCSession                  watchOS App
  ────────                   ─────────                  ───────────
     │                           │                           │
     │  User selects individual  │                           │
     │  Generate 4-digit code    │                           │
     │  Show code on screen      │                           │
     │                           │                           │
     │──── .initiate ───────────>│──── .initiate ───────────>│
     │     (individualName)      │                           │
     │                           │                    Show code entry UI
     │                           │                           │
     │                           │                    User enters code
     │                           │                           │
     │<──── .codeEntry ─────────│<──── .codeEntry ──────────│
     │      (code: "1234")       │                           │
     │                           │                           │
     │  Verify code              │                           │
     │  ┌─ Match? ─┐             │                           │
     │  │          │             │                           │
     │  ▼ YES      ▼ NO         │                           │
     │              │             │                           │
     │  │  ──── .codeFailed ────>│──── .codeFailed ─────────>│
     │  │           │            │                    Show error, retry
     │  │           │            │                           │
     │  ▼           │            │                           │
     │──── .codeVerified ───────>│──── .codeVerified ───────>│
     │  (serverURL, authToken,   │                           │
     │   individualId)           │                    Store in Keychain
     │                           │                           │
     │<──── .ack ───────────────│<──── .ack ────────────────│
     │                           │                           │
     │  Show success             │                    Start HealthKit
     │                           │                    collection
```

---

## Message Types

| Type | Direction | Payload | Purpose |
|---|---|---|---|
| `.initiate` | iOS → Watch | `individualName` | Tell Watch to show code entry UI |
| `.codeEntry` | Watch → iOS | `code` | Send the user-entered 4-digit code |
| `.codeVerified` | iOS → Watch | `serverURL`, `individualId`, `authToken`, `individualName` | Deliver provisioning configuration |
| `.codeFailed` | iOS → Watch | — | Notify Watch that code was incorrect |
| `.ack` | Watch → iOS | — | Confirm config was stored in Keychain |

---

## Security Measures

| Measure | Detail |
|---|---|
| **Code generation** | Uses `SecRandomCopyBytes` (cryptographically secure random) |
| **Code expiry** | 120 seconds from generation |
| **Brute-force protection** | Max 3 attempts, then 5-minute lockout |
| **Secure storage** | Keychain with `kSecAttrAccessibleAfterFirstUnlock` |
| **Transport** | WCSession (encrypted Bluetooth/WiFi between paired devices) |
| **Token isolation** | Watch receives a dedicated `watchAuthToken`, separate from the iOS API token |

---

## Constants

| Constant | Value | Source |
|---|---|---|
| `provisioningCodeLength` | 4 digits | `AppConstants.swift` |
| `provisioningCodeExpiry` | 120 seconds | `AppConstants.swift` |
| `maxProvisioningAttempts` | 3 | `AppConstants.swift` |
| `provisioningLockoutDuration` | 300 seconds (5 min) | `AppConstants.swift` |

---

## Key Files

### iOS

| File | Role |
|---|---|
| `Features/Provisioning/ProvisioningView.swift` | Main provisioning UI with state-driven screens |
| `Features/Provisioning/ProvisioningViewModel.swift` | Code generation, verification, attempt tracking, state management |
| `Features/Provisioning/CodeDisplayView.swift` | 4-digit code display with countdown timer |
| `Features/Provisioning/ProvisioningStatusView.swift` | Reusable status/progress component |
| `Services/WatchConnectivityManager.swift` | WCSession delegate, sends/receives `ProvisioningMessage` |

### watchOS

| File | Role |
|---|---|
| `Features/Provisioning/AwaitingSetupView.swift` | Shown when unprovisioned — "Open iPhone app" |
| `Features/Provisioning/WatchCodeEntryView.swift` | 4-digit code entry UI with secure text field |
| `Features/Provisioning/WatchErrorView.swift` | Error display with recovery guidance |
| `Services/WatchConnectivityHandler.swift` | WCSession delegate, receives config, stores in Keychain |
| `Services/WatchAppState.swift` | State machine driving UI transitions |

### Shared

| File | Role |
|---|---|
| `Shared/Models/ProvisioningMessage.swift` | Message model with type enum and optional fields |
| `Shared/Security/KeychainManager.swift` | Keychain read/write for provisioning config |
| `Shared/Constants/AppConstants.swift` | Code length, expiry, attempt limits |

---

## Re-Provisioning

To re-provision a Watch for a different individual:

1. `WatchAppState.resetToUnprovisioned()` is called, which:
   - Stops all HealthKit observer queries
   - Clears the deduplication cache
   - Clears all buffered health data from CoreData
   - Wipes the Keychain (serverURL, individualId, authToken)
   - Removes the stored individual name from UserDefaults
   - Resets sync status to `.idle`
   - Transitions mode back to `.unprovisioned`

2. The Watch returns to `AwaitingSetupView`, ready for a new provisioning cycle.

---

## Error Recovery

| Error | Watch Behavior |
|---|---|
| Code expired | iOS shows "Code expired", generates a new code |
| Wrong code (< 3 attempts) | Watch shows error, user can retry |
| Wrong code (3 attempts) | 5-minute lockout on iOS, Watch waits |
| Watch unreachable | iOS pauses at "Connecting to Watch..." |
| Config save fails | Watch transitions to `.error(.configCorrupted)` |
| Token revoked (HTTP 401 during operation) | Watch calls `recoverFromTokenRevoked()` → full re-provisioning |
| HealthKit denied | Watch shows `.error(.healthKitUnavailable)` |
