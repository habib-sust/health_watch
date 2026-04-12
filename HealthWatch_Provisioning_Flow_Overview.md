# HealthWatch Provisioning Flow

## What is Provisioning?

Provisioning is the one-time setup process that links an Apple Watch to a specific individual in the HealthWatch system. Once provisioned, the watch automatically collects health data (heart rate, steps, etc.) and sends it to the HealthWatch server for monitoring by care staff.

Think of it like pairing a new Bluetooth device — you do it once, and then it just works.

---

## Who is Involved?

| Role | Device | What They Do |
|------|--------|-------------|
| **Care Staff** | iPhone (HealthWatch app) | Selects the individual and scans the QR code |
| **Individual** | Apple Watch (HealthWatch app) | Wears the watch; taps "Provision" to show QR code |

---

## Step-by-Step Flow

### Step 1 — Start Provisioning on the Watch

The individual (or care staff assisting them) opens the HealthWatch app on the Apple Watch. The app shows a welcome screen with a **"Provision"** button.

> **What the user sees (Watch):**
> - HealthWatch logo
> - "Tap below to generate a pairing code"
> - **[Provision]** button

When tapped, the watch generates a unique QR code containing its device identifier.

---

### Step 2 — QR Code Displayed on Watch

The watch displays a QR code and a human-readable device code (e.g., `A3B7-9F2E`) underneath it.

> **What the user sees (Watch):**
> - QR code (black and white square pattern)
> - Device code: `A3B7-9F2E`
> - "Scan this code with the HealthWatch iPhone app, then tap Done."
> - **[Done]** button
> - [Cancel] link

The QR code encodes a small piece of data that identifies this specific watch. It does **not** contain any personal health information.

---

### Step 3 — Select Individual on iPhone

On the iPhone, care staff opens the HealthWatch app and navigates to the **Provision Watch** screen. They see a list of individuals they are responsible for.

> **What the user sees (iPhone):**
> - List of individuals (e.g., "John Smith", "Mary Johnson")
> - Select the individual who will wear the watch
> - **[Scan QR Code]** button becomes active

The staff member taps on the individual's name, then taps **"Scan QR Code"**.

---

### Step 4 — Scan QR Code with iPhone Camera

The iPhone opens the camera. The staff member points it at the QR code displayed on the Apple Watch.

> **What the user sees (iPhone):**
> - Live camera view
> - "Point camera at the QR code on the Apple Watch"
> - [Cancel] button

The camera automatically detects and reads the QR code — no button press needed.

---

### Step 5 — iPhone Confirms Scan and Registers Device

Once the QR code is scanned, the iPhone shows a confirmation screen and automatically registers the watch with the server.

> **What the user sees (iPhone):**
> - Green checkmark icon
> - "QR Code Scanned"
> - "Provisioning John Smith..."
> - Loading spinner
>
> Then transitions to:
> - "Registering Device"
> - "Mapping the watch to John Smith..."
>
> Then finally:
> - Green checkmark
> - "Provisioning Complete"
> - "John Smith is now set up and monitoring."
> - **[Done]** button

---

### Step 6 — Tap "Done" on the Watch

After the staff sees the scan succeed on the iPhone, they (or the individual) tap the **"Done"** button on the watch. This tells the watch to check with the server to confirm provisioning.

> **What the user sees (Watch):**
> - Loading spinner
> - "Connecting..."
> - "Verifying with server..."

The watch contacts the server to retrieve its configuration (which individual it's linked to, authentication credentials, etc.).

---

### Step 7 — Pairing Complete

Once the server confirms the pairing, the watch shows a success screen.

> **What the user sees (Watch):**
> - Green checkmark
> - "Pairing Complete"
> - "Watch is now provisioned and ready to collect health data."
> - **[Continue]** button

Tapping **"Continue"** starts health data collection. The watch begins monitoring heart rate, step count, and other health metrics in the background.

---

## After Provisioning

Once provisioned, the watch:

- Automatically collects health data in the background
- Periodically sends data to the HealthWatch server
- Shows a status screen with sync information
- Requires no further interaction from the individual

Care staff can monitor the individual's health data from the iPhone app's dashboard.

---

## Removing Provisioning (Unpairing)

Provisioning can be removed from **either device**:

### From the iPhone:
1. Go to Provision Watch screen
2. Under "Current Status", tap **"Remove Provisioning"**
3. Confirm in the dialog

### From the Watch:
1. Swipe to the Status tab
2. Tap **"Unprovision"**
3. Confirm in the dialog

Removing provisioning stops all health data collection and clears the watch's stored credentials. The watch returns to the initial welcome screen and can be provisioned again for the same or a different individual.

---

## Alternative: Manual Code Entry

If the camera cannot scan the QR code (e.g., screen glare, damaged camera), the staff can enter the device code manually:

1. On the iPhone, tap **"Enter Code Manually"** instead of "Scan QR Code"
2. Type the 8-character code shown on the watch (e.g., `A3B79F2E`)
3. Tap **"Register Device"**

The rest of the flow continues the same way.

---

## Flow Diagram

```
WATCH                                 iPHONE
=====                                 ======

[Welcome Screen]
     |
 Tap "Provision"
     |
[QR Code Displayed] ----scan----> [Camera Opens]
     |                                  |
     |                            QR auto-detected
     |                                  |
     |                            [QR Code Scanned]
     |                                  |
     |                            [Registering Device]
     |                              (server call)
     |                                  |
     |                            [Provisioning Complete]
     |                                  |
 Tap "Done"                        Tap "Done"
     |
[Connecting...]
  (server call)
     |
[Pairing Complete]
     |
 Tap "Continue"
     |
[Health Data Collection Starts]
```

---

## Security Notes

- The QR code contains only a random device identifier — **no personal or health data**.
- All communication with the server uses HTTPS encryption.
- Authentication tokens are stored securely in the device Keychain.
- Removing provisioning clears all stored credentials from the watch.

---

## Technical Summary

| Component | Technology |
|-----------|-----------|
| QR Code Generation (Watch) | [QRCode library](https://github.com/dagronf/QRCode) — Nayuki engine for watchOS |
| QR Code Scanning (iPhone) | AVFoundation `AVCaptureMetadataOutput` |
| Device Registration | REST API (`POST /api/v1/device/register`) |
| Config Polling (Watch) | REST API (`GET /api/v1/device/{id}/config`) |
| Credential Storage | iOS/watchOS Keychain |
| Health Data Collection | Apple HealthKit with background delivery |
