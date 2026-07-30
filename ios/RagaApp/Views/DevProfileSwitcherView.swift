import SwiftUI

// TEMPORARY — added on request to make switching between demo profiles fast
// while testing role-based UI. Stands in for OnboardingFlowView (see
// RootView's `devModeQuickSwitchEnabled` flag) rather than replacing it:
// nothing in OnboardingFlowView/OnboardingViewModel/AuthModels or the
// backend's /auth routes was touched. To restore real phone/OTP login,
// flip `devModeQuickSwitchEnabled` back to `false` in RootView.swift (this
// file can stay — it just goes unused) — see the "dev quick login bypass"
// project memory for the exact revert steps.
struct DevProfileSwitcherView: View {
    @EnvironmentObject private var appState: AppState
    @State private var users: [AppUser] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(users) { user in
                        Button {
                            appState.logIn(user: user)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: user.role.symbol)
                                    .foregroundStyle(Color("AccentColor"))
                                    .frame(width: 28)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(user.name)
                                        .font(.subheadline.bold())
                                        .foregroundStyle(.primary)
                                    Text(user.role.label)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if user.id == appState.currentUserId {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Color("AccentColor"))
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text("Dev Mode — Quick Profile Switch")
                } footer: {
                    Text("Phone/OTP login is temporarily bypassed. Tap a name to switch profiles instantly — no code needed.")
                }

                if appState.isLoggedIn {
                    Section {
                        Button("Log Out", role: .destructive) { appState.logOut() }
                    }
                }
            }
            .navigationTitle("Switch Profile")
            .navigationBarTitleDisplayMode(.inline)
            .task { await load() }
            .refreshable { await load() }
            .overlay {
                if isLoading && users.isEmpty {
                    ProgressView()
                }
            }
            .alert("Something went wrong", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            users = try await APIClient.shared.fetchUsers()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
