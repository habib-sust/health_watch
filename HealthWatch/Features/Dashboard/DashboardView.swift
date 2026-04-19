import SwiftUI

struct DashboardView: View {
    @StateObject private var viewModel = DashboardViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                if viewModel.isLoading {
                    ProgressView("Loading...")
                        .padding(.top, 40)
                } else if viewModel.individuals.isEmpty {
                    ContentUnavailableView(
                        "No Individuals",
                        systemImage: "person.crop.circle.badge.questionmark",
                        description: Text("Provision a watch to start monitoring an individual.")
                    )
                    .padding(.top, 40)
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.individuals) { individual in
                            NavigationLink(value: individual) {
                                IndividualCardView(individual: individual)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }

                if let error = viewModel.error {
                    HStack {
                        Image(systemName: "exclamationmark.triangle")
                        Text(error.localizedDescription)
                    }
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .padding(.horizontal)
                    .padding(.top, 4)
                }
            }
            .navigationTitle("HealthWatch")
            .navigationDestination(for: IndividualSummary.self) { individual in
                IndividualDetailView(individual: individual)
            }
            .refreshable {
                await viewModel.refresh()
            }
            .onAppear {
                viewModel.startPolling()
            }
            .onDisappear {
                viewModel.stopPolling()
            }
        }
    }
}

#Preview {
    DashboardView()
}
