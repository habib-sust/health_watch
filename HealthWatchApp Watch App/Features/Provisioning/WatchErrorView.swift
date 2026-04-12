import SwiftUI

struct WatchErrorView: View {
    let error: WatchError

    var body: some View {
        VStack(spacing: 12) {
            Spacer()

            Image(systemName: iconName)
                .font(.system(size: 32))
                .foregroundStyle(.red)

            Text(title)
                .font(.headline)
                .multilineTextAlignment(.center)

            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .padding()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(subtitle)")
    }

    private var iconName: String {
        switch error {
        case .tokenRevoked:
            return "key.slash"
        case .provisioningRequired:
            return "exclamationmark.applewatch"
        case .healthKitUnavailable:
            return "heart.slash"
        case .storageFull:
            return "externaldrive.badge.xmark"
        case .configCorrupted:
            return "gearshape.arrow.triangle.2.circlepath"
        case .keychainFailed:
            return "lock.trianglebadge.exclamationmark"
        }
    }

    private var title: String {
        switch error {
        case .tokenRevoked:
            return "Re-provisioning Required"
        case .provisioningRequired:
            return "Setup Required"
        case .healthKitUnavailable:
            return "HealthKit Unavailable"
        case .storageFull:
            return "Storage Full"
        case .configCorrupted:
            return "Configuration Error"
        case .keychainFailed:
            return "Keychain Error"
        }
    }

    private var subtitle: String {
        switch error {
        case .tokenRevoked:
            return "Open HealthWatch on iPhone to re-provision this watch."
        case .provisioningRequired:
            return "This watch needs to be set up from the iPhone app."
        case .healthKitUnavailable:
            return "HealthKit access is required for monitoring."
        case .storageFull:
            return "Local storage is full. Data will be cleared automatically."
        case .configCorrupted:
            return "Configuration is invalid. Re-provision from iPhone."
        case .keychainFailed:
            return "Failed to save credentials. Try provisioning again."
        }
    }
}
