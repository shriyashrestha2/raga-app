import SwiftUI

/// Captain-only screen for changing a team member's role. Reached via a nav
/// row a separate pass adds to TeamView, gated on
/// `Capabilities.roleManagement.canAccess`; this view re-checks that same
/// capability itself so it degrades gracefully even if reached some other
/// way (deep link, stale nav state, etc).
struct RoleManagementView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = RoleManagementViewModel()
    @State private var pendingChange: PendingRoleChange?

    private struct PendingRoleChange: Identifiable {
        let member: AppUser
        let newRole: Role
        var id: String { member.id + newRole.rawValue }
    }

    private var captainCount: Int {
        appState.users.filter { $0.role == .captain }.count
    }

    var body: some View {
        Group {
            if appState.capabilities?.roleManagement.canAccess != true {
                EmptyStateView.restrictedAccess()
                    .padding()
            } else {
                List {
                    Section {
                        ForEach(appState.users) { member in
                            RoleManagementRow(member: member, isUpdating: viewModel.isUpdating) { newRole in
                                pendingChange = PendingRoleChange(member: member, newRole: newRole)
                            }
                        }
                    } footer: {
                        Text("Changing a member's role updates what they can see and edit across the app immediately.")
                    }
                }
            }
        }
        .navigationTitle("Role Management")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            confirmationTitle,
            isPresented: Binding(
                get: { pendingChange != nil },
                set: { isPresented in if !isPresented { pendingChange = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Change Role", role: isDemotingOnlyCaptain ? .destructive : nil) {
                applyPendingChange()
            }
            Button("Cancel", role: .cancel) {
                pendingChange = nil
            }
        } message: {
            Text(confirmationMessage)
        }
        .alert("Couldn't Update Role", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { isPresented in if !isPresented { viewModel.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "Something went wrong. Please try again.")
        }
    }

    private var isDemotingOnlyCaptain: Bool {
        guard let pendingChange else { return false }
        return pendingChange.member.role == .captain && pendingChange.newRole != .captain && captainCount <= 1
    }

    private var confirmationTitle: String {
        guard let pendingChange else { return "" }
        return "Change \(pendingChange.member.name) to \(pendingChange.newRole.label)?"
    }

    private var confirmationMessage: String {
        guard let pendingChange else { return "" }
        if isDemotingOnlyCaptain {
            return "\(pendingChange.member.name) is the only Captain. Changing their role means no one on the team will have Captain access until someone else is promoted."
        }
        return "\(pendingChange.member.name) will become \(pendingChange.newRole.label) and their access across the app will update immediately."
    }

    private func applyPendingChange() {
        guard let pendingChange, let actingUserId = appState.currentUserId else { return }
        let member = pendingChange.member
        let newRole = pendingChange.newRole
        self.pendingChange = nil
        Task {
            let success = await viewModel.changeRole(memberId: member.id, to: newRole, actingUserId: actingUserId)
            if success {
                await appState.loadAll()
            }
        }
    }
}

private struct RoleManagementRow: View {
    let member: AppUser
    let isUpdating: Bool
    let onSelectRole: (Role) -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text(member.initials)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
                .frame(width: 36, height: 36)
                .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(member.name)
                    .font(.subheadline.bold())
                Label(member.role.label, systemImage: member.role.symbol)
                    .font(.caption)
                    .foregroundStyle(Color("AccentColor"))
            }

            Spacer(minLength: 0)

            if isUpdating {
                ProgressView()
                    .controlSize(.small)
            } else {
                Menu {
                    ForEach(Role.allCases, id: \.self) { role in
                        Button {
                            onSelectRole(role)
                        } label: {
                            Label(role.label, systemImage: role.symbol)
                        }
                        .disabled(role == member.role)
                    }
                } label: {
                    Label("Change", systemImage: "chevron.up.chevron.down")
                        .labelStyle(.iconOnly)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                        .background(Color(.tertiarySystemFill), in: Circle())
                }
            }
        }
        .padding(.vertical, 4)
    }
}
