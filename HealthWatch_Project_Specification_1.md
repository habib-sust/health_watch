# HEALTHWATCH
## iOS & watchOS Health Monitoring Platform — Project Specification Document

---

| Field | Value |
|---|---|
| **Document Title** | Project Specification Document |
| **Project Name** | HealthWatch — iOS & watchOS Health Monitoring Platform |
| **Version** | 1.0 |
| **Date** | April 2, 2026 |
| **Status** | Draft |
| **Classification** | Confidential |

---

## Table of Contents

1. [Introduction](#1-introduction)
2. [System Overview](#2-system-overview)
3. [User Roles & Personas](#3-user-roles--personas)
4. [Architecture & Components](#4-architecture--components)
5. [Provisioning Flow](#5-provisioning-flow)
6. [Data Collection & Transmission](#6-data-collection--transmission)
7. [iOS Staff Application](#7-ios-staff-application)
8. [watchOS Companion Application](#8-watchos-companion-application)
9. [API & Server Communication](#9-api--server-communication)
10. [Security & Privacy](#10-security--privacy)
11. [HealthKit Integration](#11-healthkit-integration)
12. [Error Handling & Edge Cases](#12-error-handling--edge-cases)
13. [Non-Functional Requirements](#13-non-functional-requirements)
14. [Assumptions & Constraints](#14-assumptions--constraints)
15. [Risks & Mitigations](#15-risks--mitigations)
16. [Future Considerations](#16-future-considerations)
17. [Glossary](#17-glossary)

---

## 1. Introduction

### 1.1 Purpose

This document provides the comprehensive specification for HealthWatch, a health data collection and monitoring platform comprising an iOS mobile application and a watchOS companion extension. It defines the system architecture, user workflows, data models, security requirements, and technical constraints necessary for development, QA, and stakeholder alignment.

### 1.2 Scope

The system enables care staff to remotely monitor the health metrics of individuals wearing Apple Watches. The platform consists of three primary components: a watchOS application that autonomously collects and transmits HealthKit data, an iOS application used by staff to provision watches and monitor health dashboards, and a backend server that receives, stores, and serves aggregated health data.

### 1.3 Intended Audience

- Product owners and stakeholders
- iOS and watchOS development teams
- Backend/API engineering teams
- QA and test engineers
- Security and compliance reviewers
- UX/UI designers

### 1.4 Definitions & Conventions

Throughout this document, "individual" refers to the person wearing the Apple Watch whose health data is being collected. "Staff" or "care staff" refers to the personnel who provision devices and monitor health data. "Provisioning" means the one-time setup process that configures a watchOS app to operate independently.

---

## 2. System Overview

### 2.1 High-Level Description

HealthWatch is designed around a decoupled architecture where the Apple Watch operates as an autonomous health data sensor after a one-time provisioning step. The individual's iPhone is only needed during the initial setup; once provisioning is complete, the watchOS app independently reads HealthKit data and periodically transmits it to a configured server endpoint. Staff members use the iOS app on their own devices to browse and monitor health data across all assigned individuals.

### 2.2 Key Design Principles

- **Minimal friction:** The individual's iPhone is used only once during setup, then never again.
- **Autonomous operation:** The watch app runs independently without requiring the paired iPhone to remain nearby or powered on.
- **Staff-centric monitoring:** Staff can oversee multiple individuals from a single device.
- **Privacy by design:** Credentials never persist on the individual's iPhone after provisioning.
- **Resilience:** The watch app handles connectivity interruptions gracefully with local buffering.

### 2.3 System Context Diagram

The system involves four key entities interacting across two phases:

| Entity | Role | Provisioning Phase | Operational Phase |
|---|---|---|---|
| Staff iPhone | Provisioning & monitoring | Active | Monitoring only |
| Individual's iPhone | One-time setup host | Active | Not required |
| Apple Watch | Health data sensor | Receives config | Autonomous collection & push |
| Backend Server | Data storage & API | Provides config data | Receives & serves data |

---

## 3. User Roles & Personas

### 3.1 Care Staff

Care staff are the primary users of the iOS application. They authenticate with organizational credentials, provision watches for individuals, and monitor health dashboards. A single staff member may be responsible for multiple individuals. Staff require minimal technical expertise; the provisioning workflow must be guided and foolproof.

### 3.2 Individual (Watch Wearer)

Individuals are passive participants. They wear the Apple Watch and do not directly interact with the iOS application after provisioning. The watchOS app should require zero user input during normal operation. Individuals are not expected to have accounts or credentials within the system.

### 3.3 System Administrator

System administrators manage the backend server, configure server URLs, manage staff accounts and individual records, and oversee system health. They do not interact with the mobile or watch applications directly.

---

## 4. Architecture & Components

### 4.1 Component Overview

| Component | Description | Platform | Language/Framework |
|---|---|---|---|
| iOS App | Staff login, provisioning, health dashboard | iOS 16+ | Swift / SwiftUI |
| watchOS App | Autonomous HealthKit data collection & push | watchOS 9+ | Swift / SwiftUI |
| Backend Server | REST API for data ingestion & retrieval | Cloud-hosted | TBD |
| WatchConnectivity | iOS↔watchOS communication layer | Apple Framework | WCSession API |

### 4.2 Communication Channels

During provisioning, the iOS app communicates with the watchOS app via Apple's WatchConnectivity framework (WCSession). This is a bidirectional channel available when both the iPhone and Apple Watch are within Bluetooth/Wi-Fi range. After provisioning, the watchOS app communicates directly with the backend server over HTTPS, using either the watch's Wi-Fi connection or the paired iPhone's network (if available). The iOS staff app communicates with the backend server independently via standard HTTPS REST calls.

### 4.3 Data Flow Summary

1. Staff logs into the iOS app on the individual's iPhone and initiates provisioning.
2. iOS app generates a verification code and sends a provisioning request to the watch via WCSession.
3. Watch displays a code-entry prompt; staff enters the code on the watch.
4. Watch sends the entered code back to the iOS app for verification.
5. On match, the iOS app transmits the server URL and individual identifier to the watch.
6. Staff logs out; the individual's iPhone is no longer involved.
7. The watch app reads HealthKit data on a schedule and POSTs it to the server.
8. Staff views aggregated data via the iOS app on their own device.

---

## 5. Provisioning Flow

### 5.1 Prerequisites

- The individual's iPhone must be paired with their Apple Watch via Bluetooth.
- The HealthWatch iOS app must be installed on the individual's iPhone.
- The corresponding HealthWatch watchOS app must be installed on the paired Apple Watch.
- The staff member must have valid authentication credentials.
- The individual must have an existing record in the backend system.

### 5.2 Step-by-Step Provisioning Sequence

| Step | Action | Component | Outcome |
|---|---|---|---|
| 1 | Staff opens the iOS app on the individual's iPhone and authenticates with their own credentials. | iOS App | Staff authenticated; session token obtained. |
| 2 | Staff selects the target individual from their assigned list. | iOS App | Individual record loaded; individual ID stored in memory. |
| 3 | iOS app verifies WCSession is active and the watch is reachable. | iOS App | WCSession.isReachable confirmed. |
| 4 | iOS app generates a random 4-digit verification code and displays it on screen. | iOS App | Code displayed to staff; code stored in memory with a 120-second expiry. |
| 5 | iOS app sends a provisioning-initiation message to the watch via WCSession.sendMessage. | WatchConnectivity | Watch receives initiation payload. |
| 6 | watchOS app displays a numeric keypad prompting for the 4-digit code. | watchOS App | Staff enters the code on the watch. |
| 7 | Watch sends the entered code back to the iOS app via WCSession reply handler. | WatchConnectivity | iOS app receives the code for verification. |
| 8 | iOS app compares the received code against the generated code. | iOS App | Match: proceed. Mismatch/timeout: show error, allow retry. |
| 9 | On successful verification, iOS app sends a configuration payload containing the server URL, individual ID, and an auth token for the watch. | WatchConnectivity | Watch stores configuration securely in Keychain. |
| 10 | Watch sends a confirmation acknowledgment back to the iOS app. | WatchConnectivity | iOS app displays success state. |
| 11 | Staff logs out of the iOS app. All session data is cleared from the individual's iPhone. | iOS App | No credentials or tokens persist on the individual's device. |

### 5.3 Verification Code Behavior

- The code is a randomly generated 4-digit numeric string (0000–9999).
- The code expires after 120 seconds. If expired, a new code must be generated.
- A maximum of 3 failed attempts is allowed before the provisioning session is locked for 5 minutes.
- The code is never persisted to disk; it exists only in memory during the active session.

### 5.4 Re-Provisioning

If a watch needs to be re-provisioned (e.g., reassigned to a different individual or server URL changed), the full provisioning flow is repeated. The new configuration overwrites the previous one stored in the watch's Keychain. Any locally buffered but unsent data from the previous configuration should be discarded upon re-provisioning.

---

## 6. Data Collection & Transmission

### 6.1 HealthKit Data Types

The watchOS app collects the following HealthKit data types. This list may be extended in future versions.

| Metric | HealthKit Identifier | Unit | Collection Frequency |
|---|---|---|---|
| Heart Rate | HKQuantityTypeIdentifier.heartRate | bpm | Real-time + periodic |
| Resting Heart Rate | HKQuantityTypeIdentifier.restingHeartRate | bpm | Daily |
| Heart Rate Variability | HKQuantityTypeIdentifier.heartRateVariabilitySDNN | ms | Periodic |
| Blood Oxygen (SpO₂) | HKQuantityTypeIdentifier.oxygenSaturation | % | Periodic |
| Step Count | HKQuantityTypeIdentifier.stepCount | count | Cumulative daily |
| Active Energy | HKQuantityTypeIdentifier.activeEnergyBurned | kcal | Cumulative daily |
| Sleep Analysis | HKCategoryTypeIdentifier.sleepAnalysis | stages | Nightly |
| Respiratory Rate | HKQuantityTypeIdentifier.respiratoryRate | breaths/min | Periodic |
| Walking Heart Rate Avg | HKQuantityTypeIdentifier.walkingHeartRateAverage | bpm | Daily |

### 6.2 Collection Schedule

The watchOS app uses a combination of HealthKit observer queries (for real-time data like heart rate) and background refresh tasks via WKApplicationRefreshBackgroundTask. The primary push cycle targets a 15-minute interval, though watchOS background scheduling is best-effort and not guaranteed to fire exactly on time. Each cycle collects all new samples since the last successful push and batches them into a single HTTP request.

### 6.3 Local Buffering

If the server is unreachable or the push fails, the collected data is stored locally on the watch using a lightweight Core Data store. On each subsequent cycle, the app attempts to transmit any buffered data along with newly collected samples. The local buffer retains data for up to 7 days; data older than this threshold is purged to manage storage constraints on the watch.

### 6.4 Transmission Payload Format

Data is transmitted as JSON over HTTPS POST to the configured server URL. Each payload contains the individual identifier, a device identifier, a timestamp, and an array of health samples. Each sample includes the HealthKit type identifier, the value, the unit, and the sample start/end timestamps.

---

## 7. iOS Staff Application

### 7.1 Authentication

Staff authenticate using organizational credentials. The app supports token-based authentication (e.g., OAuth 2.0 / JWT). Session tokens are stored in the iOS Keychain and are scoped to the staff member's device. When the app is used on an individual's iPhone for provisioning, all authentication material is cleared upon logout.

### 7.2 Core Features

| Feature | Description | Screen / Context |
|---|---|---|
| Login / Logout | Secure authentication with session management. Clean logout clears all session data. | All screens |
| Individual List | Browse assigned individuals with search, filter, and sort. Shows last-synced timestamp and status indicator. | Dashboard |
| Individual Detail | View comprehensive health data for a selected individual, including trend charts, latest readings, and historical data. | Detail View |
| Provisioning | Guided workflow to provision a watch for an individual. Includes code generation, watch communication, and confirmation. | Provisioning Screen |
| Alerts & Notifications | Configurable thresholds for health metrics. Staff receive push notifications when readings fall outside defined ranges. | Alerts Tab |
| Settings | Server configuration, notification preferences, and account management. | Settings |

### 7.3 Dashboard Design Requirements

- Show a card-based overview of each individual's current status.
- Color-coded status indicators: green (normal), amber (attention), red (critical), gray (no data / offline).
- Pull-to-refresh and automatic polling every 60 seconds when the dashboard is visible.
- Support for both light and dark mode with accessible contrast ratios.

---

## 8. watchOS Companion Application

### 8.1 Operational Modes

The watchOS app has two distinct modes. In **unprovisioned mode**, the app displays a simple "Awaiting Setup" screen and listens for provisioning messages from the paired iOS app. In **provisioned mode**, the app runs autonomously, collecting and transmitting health data per the configured schedule.

### 8.2 User Interface

The watchOS UI is deliberately minimal. In unprovisioned mode, a static informational screen is shown. During provisioning, a numeric code-entry interface is presented. In provisioned mode, the app displays a simple status indicator showing the last successful sync time and a connection status icon. No health data is displayed on the watch face itself.

### 8.3 Background Execution

The app uses WKApplicationRefreshBackgroundTask for periodic data pushes, HealthKit background delivery for real-time sample observation, and URLSession background transfers for network requests that may complete while the app is suspended. The app must handle the watchOS background execution budget carefully, as excessive resource consumption can cause the system to throttle or terminate the app.

### 8.4 Persistent Configuration

The server URL, individual identifier, and authentication token are stored in the watchOS Keychain. These values persist across app restarts and watch reboots. The provisioned state flag is stored in UserDefaults for quick startup checks.

---

## 9. API & Server Communication

### 9.1 Endpoints (Watch → Server)

| Method | Path | Purpose | Authentication |
|---|---|---|---|
| POST | /api/v1/health-data | Submit batched health samples | Auth token (Bearer) |
| GET | /api/v1/health-data/ack | Confirm receipt of buffered data | Auth token (Bearer) |
| POST | /api/v1/device/heartbeat | Periodic liveness check | Auth token (Bearer) |

### 9.2 Endpoints (iOS App → Server)

| Method | Path | Purpose | Authentication |
|---|---|---|---|
| POST | /api/v1/auth/login | Staff authentication | Credentials |
| POST | /api/v1/auth/logout | Session invalidation | Session token |
| GET | /api/v1/individuals | List assigned individuals | Session token |
| GET | /api/v1/individuals/{id}/health | Retrieve health data for an individual | Session token |
| POST | /api/v1/individuals/{id}/provision | Register provisioning event | Session token |
| GET | /api/v1/alerts | Retrieve active alerts | Session token |

### 9.3 Error Response Codes

All API endpoints return standard HTTP status codes. The watch app implements exponential backoff for retries on 5xx errors and network timeouts. A 401 response from the server indicates the watch's auth token has been revoked; the watch should enter an error state and display a "Re-provisioning Required" message.

---

## 10. Security & Privacy

### 10.1 Data in Transit

- All communication between the watch and the server occurs over HTTPS (TLS 1.2+).
- Certificate pinning is recommended for the watchOS app to prevent MITM attacks.
- WatchConnectivity messages between the iOS app and watch are encrypted by the OS.

### 10.2 Data at Rest

- Authentication tokens and server URLs are stored in the Apple Keychain on both iOS and watchOS.
- Locally buffered health data on the watch is stored in a Core Data store protected by watchOS data protection (NSFileProtectionCompleteUntilFirstUserAuthentication).
- No health data is stored on the iOS app; the iOS app reads data from the server only.

### 10.3 Credential Lifecycle

- Staff credentials are never stored on the individual's iPhone. They exist only in memory during the active session and are cleared on logout.
- The watch's auth token is scoped to the specific individual and can be revoked server-side.
- Token rotation should be supported: the server can issue a new token in response to a valid request, and the watch updates its stored token.

### 10.4 HealthKit Permissions

The watchOS app requests read-only access to the specified HealthKit data types. HealthKit authorization is requested during the provisioning flow. The iOS app does not request HealthKit permissions, as it does not read health data directly from the device.

### 10.5 Privacy Considerations

- The system must comply with applicable health data regulations (e.g., HIPAA if deployed in the US, GDPR if in the EU).
- Health data is associated with an opaque individual identifier, not with personal details, at the transport layer.
- Individuals should be informed about what data is collected and have the ability to revoke consent.

---

## 11. HealthKit Integration

### 11.1 Authorization Request

HealthKit authorization is triggered during provisioning after the verification code is confirmed. The watchOS app calls HKHealthStore.requestAuthorization(toShare:read:) for all required data types. If the user denies any permissions, the watch app stores a record of denied types and reports this to the server. Partial authorization is acceptable; the app collects whichever types are authorized.

### 11.2 Query Strategy

- **Observer queries** (HKObserverQuery) are registered for real-time data types such as heart rate to receive background delivery notifications.
- **Anchored object queries** (HKAnchoredObjectQuery) are used during each push cycle to efficiently fetch only new samples since the last anchor.
- **Statistics queries** (HKStatisticsQuery) are used for aggregate metrics like daily step counts and active energy.

### 11.3 Sample De-duplication

HealthKit may deliver duplicate samples across query executions. The app uses the sample UUID and source bundle identifier to de-duplicate before buffering and transmitting.

---

## 12. Error Handling & Edge Cases

| Scenario | Trigger | Expected Behavior |
|---|---|---|
| Watch not reachable during provisioning | WCSession.isReachable returns false | Display clear error message instructing staff to ensure the watch is nearby and unlocked. Offer a retry button. |
| Verification code mismatch | Entered code does not match generated code | Display error on both iOS and watch. Decrement remaining attempts. After 3 failures, lock provisioning for 5 minutes. |
| Verification code expired | 120-second timeout elapsed | Automatically generate a new code. Display message on iOS indicating the previous code expired. |
| Network unavailable on watch | URLSession task fails with no connectivity | Buffer data locally. Retry on next background refresh cycle with exponential backoff. |
| Server returns 401 Unauthorized | Auth token revoked or expired | Enter error state. Display "Re-provisioning Required" on watch. Notify server of token rejection. |
| HealthKit authorization denied | User denies one or more HealthKit types | Proceed with authorized types. Report denied types to server. Do not repeatedly prompt for denied types. |
| Watch storage full | Core Data buffer exceeds capacity | Purge oldest buffered data. Log a warning. Prioritize most recent samples. |
| App terminated by watchOS | Excessive background resource usage | On next launch, restore state from Keychain and Core Data. Resume normal collection cycle. |
| Re-provisioning while data buffered | New provisioning overwrites config | Discard buffered data from previous config. Begin fresh collection under new individual ID. |
| Watch unpaired from iPhone | Bluetooth pairing broken | Watch continues operating independently via Wi-Fi. Provisioning cannot occur until re-paired. |

---

## 13. Non-Functional Requirements

### 13.1 Performance

- iOS app launch-to-dashboard time: under 2 seconds on iPhone 12 or later.
- watchOS background data push cycle: complete within 15 seconds to stay within the background execution budget.
- API response time for health data retrieval: under 500ms at the 95th percentile.

### 13.2 Reliability

- The watchOS app must achieve a data delivery success rate of 99.5% or higher over any 30-day period (excluding planned server downtime).
- Local buffering ensures no data loss during transient network failures for up to 7 days.

### 13.3 Scalability

- The backend must support at least 10,000 concurrent watch devices pushing data at 15-minute intervals.
- The iOS app must handle staff members managing up to 200 individuals without UI degradation.

### 13.4 Compatibility

- iOS app: iOS 16.0 and later. iPhone 8 and later.
- watchOS app: watchOS 9.0 and later. Apple Watch Series 5 and later (requires always-on network capability).
- Backend API: Version-namespaced endpoints (v1) with backward compatibility guarantees.

### 13.5 Accessibility

- The iOS app must meet WCAG 2.1 Level AA standards.
- All interactive elements must support VoiceOver.
- Dynamic Type must be supported throughout the iOS app.

---

## 14. Assumptions & Constraints

### 14.1 Assumptions

1. Each individual has a personally owned iPhone paired with their Apple Watch.
2. The individual's iPhone will have the HealthWatch app installed by the staff member during provisioning.
3. The Apple Watch has Wi-Fi connectivity available for autonomous operation after provisioning.
4. Staff have reliable network access on their own devices for monitoring.
5. The backend server and API are developed and maintained by a separate team; this spec covers the contract, not the implementation.
6. HealthKit data types and their availability may vary by Apple Watch model and watchOS version.

### 14.2 Constraints

1. watchOS severely limits background execution time. The app must complete all work within the allotted budget or risk being throttled.
2. WatchConnectivity requires the paired iPhone to be nearby for provisioning. There is no remote provisioning capability.
3. Apple does not allow apps to programmatically read HealthKit data types that the user has explicitly denied.
4. The Apple Watch has limited storage (typically 32 GB shared with the system and other apps). The local buffer must be conservative.
5. Push notifications from the watch to the server are best-effort and may be delayed by watchOS scheduling.

---

## 15. Risks & Mitigations

| ID | Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|---|
| R-01 | watchOS background throttling | High | High | Optimize background tasks for minimal resource usage. Use HealthKit background delivery. Test on real hardware under prolonged use. |
| R-02 | Individual denies HealthKit permissions | Medium | Medium | Graceful degradation. Collect authorized types only. Report gaps to staff. |
| R-03 | Watch loses connectivity for extended periods | Medium | High | 7-day local buffer. Prioritize recent data. Alert staff via server-side absence detection. |
| R-04 | Staff provisions wrong individual | Low | High | Confirmation dialog showing individual name/ID before finalizing. Re-provisioning support. |
| R-05 | Auth token compromised | Low | Critical | Token rotation. Server-side revocation. Certificate pinning. Short token TTL with refresh mechanism. |
| R-06 | WatchConnectivity message delivery failure | Medium | Medium | Retry logic with timeout. Clear error messaging. Fall back to transferUserInfo for queued delivery. |

---

## 16. Future Considerations

The following items are out of scope for version 1.0 but are anticipated for future releases:

- **Configurable data collection profiles:** Allow administrators to define which HealthKit types to collect per individual.
- **Real-time alerts on watch:** Display critical health alerts directly on the watch face via complications.
- **Multi-watch support:** Allow a single individual to be associated with multiple watches (e.g., primary and backup).
- **Offline provisioning:** Explore pre-signed configuration bundles that could be side-loaded without real-time server communication.
- **Data export:** Allow staff to export health data in standard clinical formats (e.g., FHIR, HL7).
- **Family/caretaker portal:** A web-based dashboard for family members to view their loved one's health trends.
- **watchOS complications:** Show last sync status or a simple health indicator on the watch face.
- **Android/Wear OS support:** Extend the platform to non-Apple ecosystems.

---

## 17. Glossary

| Term | Definition |
|---|---|
| **HealthKit** | Apple's framework for reading and writing health and fitness data on iOS and watchOS. |
| **WatchConnectivity** | Apple's framework enabling communication between a paired iPhone and Apple Watch. |
| **WCSession** | The primary class in WatchConnectivity used to manage the communication session. |
| **Provisioning** | The one-time setup process that configures the watchOS app with server URL and individual identity. |
| **Individual** | A person wearing the Apple Watch whose health data is being monitored. |
| **Staff / Care Staff** | Personnel who manage and monitor individuals using the iOS application. |
| **Keychain** | Apple's secure credential storage system, used for persisting tokens and sensitive configuration. |
| **Background Refresh** | A watchOS mechanism allowing apps to perform brief updates while not in the foreground. |
| **Anchored Object Query** | A HealthKit query type that efficiently returns only new or modified samples since a saved anchor point. |
| **Certificate Pinning** | A security technique that associates a server with its expected SSL certificate to prevent interception. |
| **Exponential Backoff** | A retry strategy where the wait time between retries increases exponentially after each failure. |

---

*Confidential — HealthWatch Project Specification v1.0 — April 2026*
