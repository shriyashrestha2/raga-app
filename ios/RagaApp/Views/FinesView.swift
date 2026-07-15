import SwiftUI

/// Fines list — managers (Captain/Finance/Logistics) see and manage everyone's
/// fines; every other role sees only their own, read-only. Server-side
/// filtering is authoritative (see backend/src/routes/fines.ts); the
/// `canManageAny` capability flag here only drives which controls render.
struct FinesView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = FinesViewModel()
    @State private var showingNewFine = false

    private var canManage: Bool {
        appState.capabilities?.fines.canManageAny == true
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if viewModel.fines.isEmpty && !viewModel.isLoading {
                    EmptyStateView(
                        icon: "dollarsign.circle",
                        title: "No fines",
                        message: canManage
                            ? "No fines have been issued yet. Tap + to fine a team member."
                            : "You don't have any fines on record. Nice.",
                        actionTitle: canManage ? "New Fine" : nil
                    ) { showingNewFine = true }
                } else {
                    ForEach(viewModel.fines) { fine in
                        FineCardView(
                            fine: fine,
                            canManage: canManage,
                            onSetStatus: { status in
                                guard let userId = appState.currentUserId else { return }
                                Task { await viewModel.setStatus(fineId: fine.id, status: status, userId: userId) }
                            },
                            onDelete: {
                                guard let userId = appState.currentUserId else { return }
                                Task { await viewModel.delete(fineId: fine.id, userId: userId) }
                            }
                        )
                    }
                }
            }
            .padding(16)
        }
        .navigationTitle("Fines")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if canManage {
                ToolbarItem(placement: .primaryAction) {
                    Button { showingNewFine = true } label: { Image(systemName: "plus") }
                }
            }
        }
        .task { await load() }
        .refreshable { await load() }
        .sheet(isPresented: $showingNewFine) {
            NewFineSheet(users: appState.users) { targetUserId, amountCents, reason in
                guard let userId = appState.currentUserId else { return }
                Task { await viewModel.createFine(targetUserId: targetUserId, amountCents: amountCents, reason: reason, userId: userId) }
            }
        }
    }

    private func load() async {
        guard let userId = appState.currentUserId else { return }
        await viewModel.load(userId: userId)
    }
}

private struct NewFineSheet: View {
    @Environment(\.dismiss) private var dismiss
    let users: [AppUser]
    let onCreate: (String, Int, String) -> Void

    @State private var selectedUserId: String?
    @State private var amountText: String = ""
    @State private var reason: String = ""

    private var amountCents: Int? {
        guard let dollars = Double(amountText), dollars > 0 else { return nil }
        return Int((dollars * 100).rounded())
    }

    private var isValid: Bool {
        selectedUserId != nil && amountCents != nil && !reason.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Team Member") {
                    Picker("Member", selection: $selectedUserId) {
                        Text("Select a member").tag(String?.none)
                        ForEach(users.sorted(by: { $0.name < $1.name })) { user in
                            Text("\(user.name) · \(user.role.label)").tag(Optional(user.id))
                        }
                    }
                }
                Section("Amount") {
                    HStack {
                        Text("$")
                            .foregroundStyle(.secondary)
                        TextField("0.00", text: $amountText)
                            .keyboardType(.decimalPad)
                    }
                }
                Section("Reason") {
                    TextField("e.g. Missed practice", text: $reason, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .navigationTitle("New Fine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Send") {
                        guard let selectedUserId, let amountCents else { return }
                        onCreate(selectedUserId, amountCents, reason.trimmingCharacters(in: .whitespacesAndNewlines))
                        dismiss()
                    }
                    .disabled(!isValid)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
