import SwiftUI

struct ProvisioningView: View {
    @EnvironmentObject var watchManager: WatchConnectivityManager
    @StateObject private var viewModel: ProvisioningViewModel

    init(watchManager: WatchConnectivityManager) {
        _viewModel = StateObject(wrappedValue: ProvisioningViewModel(watchManager: watchManager))
    }

    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.state {
                case .selectIndividual:
                    individualSelectionView

                case .checkingWatchConnection:
                    ProvisioningStatusView(
                        icon: "applewatch",
                        title: "Checking Watch Connection",
                        subtitle: "Looking for paired Apple Watch...",
                        isLoading: true
                    )

                case .watchNotReachable:
                    ProvisioningStatusView(
                        icon: "applewatch.slash",
                        title: "Watch Not Reachable",
                        subtitle: "Make sure the Apple Watch is nearby, unlocked, and the HealthWatch app is installed.",
                        isLoading: false,
                        actionTitle: "Try Again"
                    ) {
                        Task { await viewModel.initiateProvisioning() }
                    }

                case .displayingCode(let code, let expiresAt):
                    CodeDisplayView(code: code, expiresAt: expiresAt)

                case .waitingForCodeEntry:
                    ProvisioningStatusView(
                        icon: "keyboard",
                        title: "Enter Code on Watch",
                        subtitle: "Enter the 4-digit code shown above on the Apple Watch to confirm.",
                        isLoading: true
                    )

                case .verifyingCode:
                    ProvisioningStatusView(
                        icon: "checkmark.shield",
                        title: "Verifying Code",
                        subtitle: "Checking the entered code...",
                        isLoading: true
                    )

                case .codeAccepted:
                    ProvisioningStatusView(
                        icon: "checkmark.circle",
                        title: "Code Accepted",
                        subtitle: "Sending configuration to watch...",
                        isLoading: true
                    )

                case .codeFailed(let attemptsRemaining):
                    ProvisioningStatusView(
                        icon: "xmark.circle",
                        title: "Incorrect Code",
                        subtitle: "\(attemptsRemaining) attempt\(attemptsRemaining == 1 ? "" : "s") remaining. Ask the wearer to try again.",
                        isLoading: false
                    )

                case .sendingConfig:
                    ProvisioningStatusView(
                        icon: "arrow.triangle.2.circlepath",
                        title: "Sending Configuration",
                        subtitle: "Transferring settings to the watch...",
                        isLoading: true
                    )

                case .success:
                    ProvisioningStatusView(
                        icon: "checkmark.circle.fill",
                        title: "Provisioning Complete",
                        subtitle: "\(viewModel.selectedIndividual?.name ?? "Watch") is now set up and monitoring.",
                        isLoading: false,
                        iconColor: .green,
                        actionTitle: "Done"
                    ) {
                        Task { await viewModel.retryProvisioning() }
                    }

                case .locked(let unlockAt):
                    ProvisioningStatusView(
                        icon: "lock.fill",
                        title: "Too Many Attempts",
                        subtitle: "Provisioning is locked. Try again after \(unlockAt.formatted(date: .omitted, time: .shortened)).",
                        isLoading: false,
                        iconColor: .red
                    )

                case .error(let message):
                    ProvisioningStatusView(
                        icon: "exclamationmark.triangle",
                        title: "Error",
                        subtitle: message,
                        isLoading: false,
                        iconColor: .orange,
                        actionTitle: "Start Over"
                    ) {
                        Task { await viewModel.retryProvisioning() }
                    }
                }
            }
            .navigationTitle("Provision Watch")
            .animation(.default, value: viewModel.state)
        }
    }

    // MARK: - Individual Selection

    private var individualSelectionView: some View {
        List {
            Section {
                ForEach(viewModel.availableIndividuals) { individual in
                    Button {
                        viewModel.selectedIndividual = individual
                    } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(individual.name)
                                    .font(.body)
                                Text(individual.id)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if viewModel.selectedIndividual?.id == individual.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                    .tint(.primary)
                }
            } header: {
                Text("Select Individual")
            } footer: {
                Text("Choose the individual whose Apple Watch you want to provision.")
            }

            Section {
                Button {
                    Task { await viewModel.initiateProvisioning() }
                } label: {
                    HStack {
                        Spacer()
                        Label("Begin Provisioning", systemImage: "applewatch.and.arrow.forward")
                            .font(.headline)
                        Spacer()
                    }
                }
                .disabled(viewModel.selectedIndividual == nil)
            }
        }
    }
}
