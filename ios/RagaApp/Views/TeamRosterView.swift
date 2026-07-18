import SwiftUI

/// Main Team Roster / Team Info screen. Header card shows the singleton
/// TeamInfo row (team name/season/description) with a push-to-edit
/// affordance gated by `capabilities.teamInfo.canEdit`; below it, every
/// member from `appState.users` (already loaded app-wide — not refetched
/// here) grouped by role. Tapping a member row pushes into
/// TeamInfoEditView for that member when the viewer can edit; Returner/Newbie
/// get a view-only roster, since the server would 403 their PATCH anyway
/// (backend/src/permissions.ts's canEditTeamInfo).
///
/// No NavigationStack of its own — like AttendanceView, this is meant to be
/// pushed onto TeamView's existing stack.
struct TeamRosterView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = TeamRosterViewModel()

    private var canEdit: Bool { appState.capabilities?.teamInfo.canEdit == true }

    private static let roleOrder: [Role] = [.captain, .finance, .production, .logistics, .pr, .returner, .newbie]

    private var groupedMembers: [(role: Role, members: [AppUser])] {
        Self.roleOrder.compactMap { role in
            let members = appState.users.filter { $0.role == role }.sorted { $0.name < $1.name }
            return members.isEmpty ? nil : (role, members)
        }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                teamInfoCard

                if appState.users.isEmpty {
                    EmptyStateView(icon: "person.3", title: "No roster yet", message: "Team members will show up here once added.")
                } else {
                    ForEach(groupedMembers, id: \.role) { group in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(group.role.label.uppercased())
                                .font(.caption2.bold())
                                .foregroundStyle(.secondary)
                                .padding(.leading, 4)

                            ForEach(group.members) { member in
                                memberRow(member)
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
        .navigationTitle("Team Roster")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .refreshable { await load() }
    }

    private func load() async {
        guard let userId = appState.currentUserId else { return }
        await viewModel.loadTeamInfo(userId: userId)
    }

    @ViewBuilder
    private var teamInfoCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(viewModel.teamInfo?.teamName ?? "Loading…")
                        .font(.title3.bold())
                    if let season = viewModel.teamInfo?.season {
                        Text(season)
                            .font(.caption.bold())
                            .foregroundStyle(Color("AccentColor"))
                    }
                }
                Spacer(minLength: 8)

                if canEdit, let teamInfo = viewModel.teamInfo {
                    NavigationLink {
                        TeamInfoEditView(viewModel: viewModel, target: .teamInfo(teamInfo))
                    } label: {
                        Image(systemName: "pencil.circle.fill")
                            .font(.title2)
                            .foregroundStyle(Color("AccentColor"))
                    }
                    .buttonStyle(.plain)
                }
            }

            if let description = viewModel.teamInfo?.description, !description.isEmpty {
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(Color(.separator), lineWidth: 0.5))
    }

    @ViewBuilder
    private func memberRow(_ member: AppUser) -> some View {
        if canEdit {
            NavigationLink {
                TeamInfoEditView(viewModel: viewModel, target: .member(member)) { updated in
                    if let idx = appState.users.firstIndex(where: { $0.id == updated.id }) {
                        appState.users[idx] = updated
                    }
                }
            } label: {
                RosterRowView(member: member, canEdit: true)
            }
            .buttonStyle(.plain)
        } else {
            RosterRowView(member: member, canEdit: false)
        }
    }
}
