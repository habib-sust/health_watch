# HealthWatch — Watch App Feature Flow

## Overview

The HealthWatch watchOS app serves as a health monitoring companion for individuals under care. It provides three core features: **Daily Activity tracking**, **Assistance alerts**, and **Device Provisioning**. After the watch is provisioned (linked to an individual), the wearer can view their health data at a glance and send emergency alerts to staff.

---

## Features at a Glance

| Feature | Purpose | Tab |
|---------|---------|-----|
| **Daily Activity** | View steps, heart rate, and sleep data | First tab |
| **Assistance Alert** | Request assistance from staff | Second tab |
| **Device Status** | View connection and sync status | Third tab |
| **Provisioning** | Link the watch to an individual's record | Shown before provisioning |

---

## 1. First Launch — Provisioning

Before the watch can be used, it must be linked to an individual's health record.

**What the wearer sees:**

1. A welcome screen with a "Provision" button
2. Tapping it displays a unique device code (as a QR code and text)
3. A caregiver scans the code using the iPhone app or enters it manually
4. The watch waits and automatically detects when provisioning is complete
5. Once linked, the watch transitions to the main activity screen

**After provisioning:**
- The watch remembers the link (even after reboot)
- The wearer's name appears in the status footer
- To unprovision, the caregiver uses the iPhone app

---

## 2. Daily Activity

The main screen of the watch shows a scrollable dashboard with three health cards.

### Steps Card

- Shows today's total step count
- Displays a progress bar toward a daily goal (5,000 steps)
- Shows percentage of goal completed
- **Tap to see more:** hourly step breakdown as a bar chart

### Heart Rate Card

- Shows the most recent heart rate reading prominently (e.g., "72 BPM")
- Below it: resting heart rate and today's range (min-max)
- Shows how long ago the last reading was taken
- **Tap to see more:**
  - Resting heart rate and min/max stats
  - A visual range bar showing where the current reading falls
  - A line chart of heart rate over the last 3 hours

### Sleep Card

- Shows total sleep duration from last night (e.g., "7h 23m")
- Displays a color-coded bar showing sleep stages (Deep, Core, REM, Awake)
- Shows bedtime and wake time
- Shows sleep efficiency percentage
- **Tap to see more:**
  - Full stage breakdown bar with color legend
  - Timeline chart showing when each sleep stage occurred
  - Detailed stats: Deep, Core, REM, Awake durations and efficiency

**When there's no data:**
- Steps shows "0" with an empty progress bar
- Heart rate shows "--" instead of a number
- Sleep shows "No sleep data recorded" with a friendly message

**Data refreshes automatically** every 60 seconds and whenever new health data is recorded.

---

## 3. Health Data Permission

On first use after provisioning, the watch asks for permission to read health data.

**What the wearer sees:**

1. An explanation screen describing what data Therap needs and why:
   - Steps: track daily activity toward a goal
   - Heart Rate: monitor current and resting heart rate
   - Sleep: review sleep duration and quality
2. A privacy note: "Your data stays on this device and is never shared without your knowledge"
3. Tapping "Continue" shows the Apple Health permission prompt
4. After granting access, data loads immediately

**If permission is denied:**
- A screen explains that health access is required
- A "Grant Access" button allows the wearer to try again

---

## 4. Assistance Alert

The Assistance feature allows the wearer to quickly request help from staff.

**What the wearer sees:**

1. Swipe to the Assistance tab (second page)
2. A large orange "Request Assistance" button fills the screen
3. Tapping it:
   - The watch vibrates to confirm
   - The button changes to a green checkmark with "Alert Sent"
   - A message reads "Staff has been notified"
4. After 5 seconds, the button resets so it can be used again

**What happens behind the scenes:**
- The watch sends the alert to the paired iPhone
- The iPhone displays a notification (even if the app is in the foreground):
  - Title: "Assistance Alert"
  - Message: an individual has requested assistance
- In production, this would notify staff via the server

---

## 5. Device Status

The third tab shows the watch's current status.

- Individual name (who this watch is linked to)
- Last sync timestamp
- Connection status

---

## Navigation Flow

```
App Launch
    |
    v
Provisioned? ──No──> Provisioning Screen
    |                       |
   Yes                  Complete
    |                       |
    v                       v
┌─────────────────────────────────┐
│         Tab View (swipe)        │
│                                 │
│  Tab 1: Daily Activity          │
│    ├── Steps Card ──> Detail    │
│    ├── Heart Rate Card ──> Detail│
│    └── Sleep Card ──> Detail    │
│                                 │
│  Tab 2: Assistance Alert               │
│                                 │
│  Tab 3: Device Status           │
└─────────────────────────────────┘
```

---

## Data Sources

| Metric | Source | Update Frequency |
|--------|--------|-----------------|
| Steps | Apple Health (pedometer) | Real-time + 60s refresh |
| Heart Rate | Apple Health (optical sensor) | When new readings arrive |
| Resting Heart Rate | Apple Health (calculated daily) | Once per day |
| Sleep | Apple Health (sleep tracking) | After each sleep session |

---

## Sleep Data Details

- The watch looks at the **last 18 hours** of sleep data
- If multiple sleep sessions exist (e.g., a nap and nighttime sleep), it shows the **most recent session**
- Sleep stages tracked: **Deep** (purple), **Core** (indigo), **REM** (cyan), **Awake** (orange)
- **Sleep efficiency** = time actually asleep / total time in bed
- If the watch or a connected device doesn't track sleep stages, it shows total sleep time only
