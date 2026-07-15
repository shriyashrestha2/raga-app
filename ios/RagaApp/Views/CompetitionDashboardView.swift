import SwiftUI

/// Competition Dashboard: every role sees the shared schedule; the
/// finance/production/logistics section cards render only when the
/// decoded `CompetitionItem` actually carries that section's data (the
/// server omits keys the caller's role can't see), so Dancer/Newbie simply
/// see no section cards at all rather than a locked placeholder.
struct CompetitionDashboardView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = CompetitionDashboardViewModel()

    private var editableSection: String? {
        appState.capabilities?.competitionDashboard.editableSection
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 12) {
                    if viewModel.competitions.isEmpty && !viewModel.isLoading {
                        EmptyStateView(
                            icon: "trophy",
                            title: "No competitions yet",
                            message: "Upcoming competitions and their schedules will show up here."
                        )
                    } else {
                        ForEach(viewModel.competitions) { competition in
                            NavigationLink {
                                CompetitionDetailView(
                                    competitionId: competition.id,
                                    editableSection: editableSection,
                                    viewModel: viewModel
                                )
                            } label: {
                                CompetitionListCardView(competition: competition)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground))
            .refreshable { await load() }
            .navigationTitle("Competitions")
            .navigationBarTitleDisplayMode(.inline)
        }
        .task { await load() }
        .alert("Error", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private func load() async {
        guard let userId = appState.currentUserId else { return }
        await viewModel.load(userId: userId)
    }
}

private struct CompetitionListCardView: View {
    let competition: CompetitionItem

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 2) {
                Text(competition.date, format: .dateTime.month(.abbreviated))
                    .font(.caption2.bold())
                    .foregroundStyle(.white.opacity(0.75))
                Text(competition.date, format: .dateTime.day())
                    .font(.title2.bold())
                    .foregroundStyle(.white)
            }
            .frame(width: 64)
            .frame(maxHeight: .infinity)
            .background(Color("AccentColor"))

            VStack(alignment: .leading, spacing: 4) {
                Text(competition.name)
                    .font(.subheadline.bold())
                if let location = competition.location, !location.isEmpty {
                    Label(location, systemImage: "mappin.and.ellipse")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                if !competition.scheduleItems.isEmpty {
                    Label("\(competition.scheduleItems.count) schedule item\(competition.scheduleItems.count == 1 ? "" : "s")", systemImage: "clock")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(14)
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .padding(.trailing, 14)
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(Color(.separator), lineWidth: 0.5))
    }
}

private struct CompetitionDetailView: View {
    let competitionId: String
    let editableSection: String?
    @ObservedObject var viewModel: CompetitionDashboardViewModel
    @EnvironmentObject private var appState: AppState

    private var competition: CompetitionItem? {
        viewModel.competitions.first(where: { $0.id == competitionId })
    }

    private func isEditable(_ section: String) -> Bool {
        editableSection == "ALL" || editableSection == section
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                if let competition {
                    header(for: competition)
                    scheduleSection(for: competition)

                    if let finance = competition.financeSection {
                        CompSectionCardView(
                            kind: .finance(finance),
                            isEditable: isEditable("FINANCE"),
                            onSaveFinance: { budgetCents, spentCents, notes in
                                guard let userId = appState.currentUserId else { return }
                                Task { await viewModel.updateFinance(competitionId: competitionId, budgetCents: budgetCents, spentCents: spentCents, notes: notes, userId: userId) }
                            }
                        )
                    }

                    if let production = competition.productionSection {
                        CompSectionCardView(
                            kind: .production(production),
                            isEditable: isEditable("PRODUCTION"),
                            onSaveProduction: { music, costume, notes in
                                guard let userId = appState.currentUserId else { return }
                                Task { await viewModel.updateProduction(competitionId: competitionId, musicStatus: music, costumeStatus: costume, notes: notes, userId: userId) }
                            }
                        )
                    }

                    if let logistics = competition.logisticsSection {
                        CompSectionCardView(
                            kind: .logistics(logistics),
                            isEditable: isEditable("LOGISTICS"),
                            onSaveLogistics: { travel, lodging, transportation in
                                guard let userId = appState.currentUserId else { return }
                                Task { await viewModel.updateLogistics(competitionId: competitionId, travelPlan: travel, lodging: lodging, transportationNotes: transportation, userId: userId) }
                            }
                        )
                    }
                } else {
                    EmptyStateView.restrictedAccess()
                }
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(competition?.name ?? "Competition")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func header(for competition: CompetitionItem) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(competition.date, format: .dateTime.weekday(.wide).month(.abbreviated).day().year())
                .font(.caption)
                .foregroundStyle(.secondary)
            if let location = competition.location, !location.isEmpty {
                Label(location, systemImage: "mappin.and.ellipse")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func scheduleSection(for competition: CompetitionItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Schedule", systemImage: "clock.fill")
                .font(.subheadline.bold())
                .foregroundStyle(Color("AccentColor"))

            if competition.scheduleItems.isEmpty {
                Text("No schedule items yet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(competition.scheduleItems.enumerated()), id: \.element.id) { index, item in
                        if index > 0 { Divider() }
                        HStack(alignment: .top, spacing: 10) {
                            Text(item.time, format: .dateTime.hour().minute())
                                .font(.caption.bold())
                                .foregroundStyle(Color("AccentColor"))
                                .frame(width: 64, alignment: .leading)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.label)
                                    .font(.caption.bold())
                                if let notes = item.notes, !notes.isEmpty {
                                    Text(notes)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(Color(.separator), lineWidth: 0.5))
    }
}
