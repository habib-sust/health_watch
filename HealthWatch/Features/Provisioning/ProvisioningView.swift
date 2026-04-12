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

                case .scanningQR:
                    scannerView

                case .scannedQR:
                    ProvisioningStatusView(
                        icon: "checkmark.circle.fill",
                        title: "QR Code Scanned",
                        subtitle: "Provisioning \(viewModel.selectedIndividual?.name ?? "watch")...",
                        isLoading: true,
                        iconColor: .green
                    )

                case .enteringCode:
                    codeEntryView

                case .registeringDevice:
                    ProvisioningStatusView(
                        icon: "arrow.triangle.2.circlepath",
                        title: "Registering Device",
                        subtitle: "Mapping the watch to \(viewModel.selectedIndividual?.name ?? "individual")...",
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
                        viewModel.startOver()
                    }

                case .error(let message):
                    ProvisioningStatusView(
                        icon: "exclamationmark.triangle",
                        title: "Error",
                        subtitle: message,
                        isLoading: false,
                        iconColor: .orange,
                        actionTitle: "Start Over"
                    ) {
                        viewModel.startOver()
                    }
                }
            }
            .navigationTitle("Provision Watch")
            .animation(.default, value: viewModel.state)
        }
    }

    // MARK: - QR Scanner

    private var scannerView: some View {
        ZStack(alignment: .bottom) {
            QRScannerView(
                onCodeScanned: { payload in
                    Task { await viewModel.handleScannedQR(payload: payload) }
                },
                onError: { error in
                    viewModel.state = .error(error)
                }
            )
            .ignoresSafeArea()

            VStack(spacing: 12) {
                Text("Point camera at the QR code on the Apple Watch")
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))

                Button("Cancel") {
                    viewModel.startOver()
                }
                .buttonStyle(.borderedProminent)
                .tint(.gray)
            }
            .padding(.bottom, 40)
        }
    }

    // MARK: - Code Entry

    private var codeEntryView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "applewatch")
                .font(.system(size: 48))
                .foregroundStyle(.blue)

            Text("Enter Pairing Code")
                .font(.title2.bold())

            Text("Enter the code displayed on the Apple Watch")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            TextField("XXXX-XXXX", text: $viewModel.deviceCodeInput)
                .font(.system(size: 32, weight: .bold, design: .monospaced))
                .multilineTextAlignment(.center)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .keyboardType(.asciiCapable)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray6))
                )
                .padding(.horizontal, 40)

            Button {
                Task { await viewModel.submitDeviceCode() }
            } label: {
                HStack {
                    Spacer()
                    Label("Register Device", systemImage: "checkmark.circle")
                        .font(.headline)
                    Spacer()
                }
                .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.deviceCodeInput.replacingOccurrences(of: "-", with: "").replacingOccurrences(of: " ", with: "").count < 8)
            .padding(.horizontal)

            Button("Cancel") {
                viewModel.startOver()
            }
            .foregroundStyle(.secondary)

            Spacer()
        }
        .padding()
    }

    // MARK: - Individual Selection

    private var individualSelectionView: some View {
        List {
            // Show current provisioning status
            if let provisionedId = viewModel.provisionedIndividualId,
               let provisionedName = viewModel.availableIndividuals.first(where: { $0.id == provisionedId })?.name {
                Section {
                    HStack {
                        Image(systemName: "applewatch")
                            .foregroundStyle(.blue)
                            .font(.title2)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Watch Provisioned")
                                .font(.headline)
                            Text(provisionedName)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                    .padding(.vertical, 4)

                    Button(role: .destructive) {
                        viewModel.showRemoveConfirmation = true
                    } label: {
                        HStack {
                            Spacer()
                            Label("Remove Provisioning", systemImage: "xmark.circle")
                                .font(.subheadline.weight(.medium))
                            Spacer()
                        }
                    }
                } header: {
                    Text("Current Status")
                }
            }

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
                            if individual.id == viewModel.provisionedIndividualId {
                                Label("Provisioned", systemImage: "applewatch")
                                    .font(.caption)
                                    .foregroundStyle(.blue)
                            }
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
                    viewModel.beginScanning()
                } label: {
                    HStack {
                        Spacer()
                        Label("Scan QR Code", systemImage: "qrcode.viewfinder")
                            .font(.headline)
                        Spacer()
                    }
                }
                .disabled(viewModel.selectedIndividual == nil)

                Button {
                    viewModel.beginCodeEntry()
                } label: {
                    HStack {
                        Spacer()
                        Label("Enter Code Manually", systemImage: "keyboard")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                }
                .disabled(viewModel.selectedIndividual == nil)
            }
        }
        .alert("Remove Provisioning?", isPresented: $viewModel.showRemoveConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Remove", role: .destructive) {
                Task { await viewModel.removeProvisioning() }
            }
        } message: {
            Text("This will unpair the Apple Watch and stop health data collection. The watch will need to be provisioned again.")
        }
    }
}
