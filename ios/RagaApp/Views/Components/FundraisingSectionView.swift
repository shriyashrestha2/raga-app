import SwiftUI

/// Fundraising tab: total raised, a per-source breakdown chart, a few
/// summary stats, and a log-new-fund form. Board roles can view totals
/// (see Capabilities.fundraising.canViewAny — non-board members never reach
/// this view, since TeamView hides the tab entirely for them); only Finance
/// chairs/Captains can log a new fund.
struct FundraisingSectionView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = FundsViewModel()
    @State private var showingNewFund = false

    private var canManage: Bool {
        appState.capabilities?.fundraising.canManageAny == true
    }

    private var totalCents: Int {
        viewModel.funds.reduce(0) { $0 + $1.amountCents }
    }

    private var bySource: [FundingSlice] {
        let grouped = Dictionary(grouping: viewModel.funds, by: \.source)
        let slices: [FundingSlice] = grouped.map { source, funds in
            let total = funds.reduce(0) { $0 + $1.amountCents }
            return FundingSlice(source: source, amountCents: total)
        }
        return slices.sorted { $0.amountCents > $1.amountCents }
    }

    private var largestContribution: FundItem? {
        viewModel.funds.max(by: { $0.amountCents < $1.amountCents })
    }

    private var mostRecent: FundItem? {
        viewModel.funds.max(by: { $0.dateAdded < $1.dateAdded })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Fundraising")
                .font(.title3.bold())

            if viewModel.funds.isEmpty && !viewModel.isLoading {
                EmptyStateView(
                    icon: "chart.pie.fill",
                    title: "No funds logged yet",
                    message: canManage ? "Log the first fund below." : "Fundraising totals will show up here once logged."
                )
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total Raised")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text((Double(totalCents) / 100).formatted(.currency(code: "USD")))
                        .font(.largeTitle.bold())
                        .foregroundStyle(Color("AccentColor"))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(Color(.separator), lineWidth: 0.5))

                FundingBreakdownChart(slices: bySource)

                HStack(spacing: 12) {
                    StatTileView(icon: "list.bullet", value: "\(bySource.count)", label: "Sources")
                    if let largestContribution {
                        StatTileView(
                            icon: "arrow.up.circle.fill",
                            value: (Double(largestContribution.amountCents) / 100).formatted(.currency(code: "USD")),
                            label: "Largest gift"
                        )
                    }
                    if let mostRecent {
                        StatTileView(
                            icon: "clock.fill",
                            value: mostRecent.source,
                            label: "Recent · \(mostRecent.dateAdded.formatted(date: .abbreviated, time: .omitted))"
                        )
                    }
                }
            }

            if canManage {
                Button {
                    showingNewFund = true
                } label: {
                    Label("Log New Fund", systemImage: "plus.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(Color("AccentColor"))
            }
        }
        .task { await load() }
        .sheet(isPresented: $showingNewFund) {
            NewFundSheet { amountCents, source, dateAdded in
                guard let userId = appState.currentUserId else { return }
                Task { await viewModel.createFund(amountCents: amountCents, source: source, dateAdded: dateAdded, userId: userId) }
            }
        }
    }

    private func load() async {
        guard let userId = appState.currentUserId else { return }
        await viewModel.load(userId: userId)
    }
}

private struct NewFundSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onCreate: (Int, String, Date) -> Void

    @State private var amountText: String = ""
    @State private var source: String = ""
    @State private var dateAdded: Date = Date()

    private var amountCents: Int? {
        guard let dollars = Double(amountText), dollars > 0 else { return nil }
        return Int((dollars * 100).rounded())
    }

    private var isValid: Bool {
        amountCents != nil && !source.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Amount") {
                    HStack {
                        Text("$").foregroundStyle(.secondary)
                        TextField("0.00", text: $amountText)
                            .keyboardType(.decimalPad)
                    }
                }
                Section("Source") {
                    TextField("e.g. Bake Sale, Alumni Sponsor", text: $source)
                }
                Section("Date Added") {
                    DatePicker("Date", selection: $dateAdded, displayedComponents: .date)
                }
            }
            .navigationTitle("Log New Fund")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard let amountCents else { return }
                        onCreate(amountCents, source.trimmingCharacters(in: .whitespacesAndNewlines), dateAdded)
                        dismiss()
                    }
                    .disabled(!isValid)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
