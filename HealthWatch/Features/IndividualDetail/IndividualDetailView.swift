import SwiftUI

struct IndividualDetailView: View {
    let individual: IndividualSummary
    @StateObject private var viewModel: IndividualDetailViewModel

    init(individual: IndividualSummary) {
        self.individual = individual
        self._viewModel = StateObject(wrappedValue: IndividualDetailViewModel(individual: individual))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Time range picker
                Picker("Time Range", selection: $viewModel.selectedTimeRange) {
                    ForEach(TimeRange.allCases) { range in
                        Text(range.rawValue).tag(range)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                if viewModel.isLoading {
                    ProgressView()
                        .padding(.top, 40)
                } else {
                    // Summary row
                    summarySection

                    // Vitals section
                    sectionHeader("Vitals")
                    HealthMetricChartView(
                        title: "Heart Rate",
                        samples: viewModel.heartRateSamples,
                        unit: "BPM",
                        color: .red,
                        chartStyle: .line
                    )
                    .padding(.horizontal)

                    HealthMetricChartView(
                        title: "Blood Oxygen",
                        samples: viewModel.oxygenSamples,
                        unit: "%",
                        color: .blue,
                        chartStyle: .line
                    )
                    .padding(.horizontal)

                    HealthMetricChartView(
                        title: "Respiratory Rate",
                        samples: viewModel.respiratoryRateSamples,
                        unit: "breaths/min",
                        color: .teal,
                        chartStyle: .line
                    )
                    .padding(.horizontal)

                    // Activity section
                    sectionHeader("Activity")
                    HealthMetricChartView(
                        title: "Steps",
                        samples: viewModel.stepSamples,
                        unit: "steps",
                        color: .orange,
                        chartStyle: .bar
                    )
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .navigationTitle(individual.name)
        .navigationBarTitleDisplayMode(.large)
        .task {
            await viewModel.loadData()
        }
        .onChange(of: viewModel.selectedTimeRange) {
            Task { await viewModel.loadData() }
        }
    }

    // MARK: - Summary Section

    private var summarySection: some View {
        HStack(spacing: 12) {
            if let hr = viewModel.heartRateSamples.last?.value {
                MetricRowView(
                    icon: "heart.fill",
                    title: "Heart Rate",
                    value: "\(Int(hr))",
                    unit: "BPM",
                    color: .red
                )
            }
            if let spo2 = viewModel.oxygenSamples.last?.value {
                MetricRowView(
                    icon: "lungs.fill",
                    title: "SpO2",
                    value: String(format: "%.1f", spo2),
                    unit: "%",
                    color: .blue
                )
            }
        }
        .padding(.horizontal)
    }

    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.title3.bold())
            Spacer()
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }
}
