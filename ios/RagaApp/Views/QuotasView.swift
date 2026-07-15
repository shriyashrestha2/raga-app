import SwiftUI

/// Quota list — managers (Captain/Finance only, a smaller set than
/// fines-management) see and manage everyone's quota progress; every other
/// role sees only their own, read-only (they can view but never update
/// their own progress — that's a manager action). Server-side filtering is
/// authoritative (see backend/src/routes/quotas.ts); the `canManageAny`
/// capability flag here only drives which controls render.
struct QuotasView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = QuotasViewModel()
    @State private var showingNewQuota = false

    private var canManage: Bool {
        appState.capabilities?.quotas.canManageAny == true
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if viewModel.quotas.isEmpty && !viewModel.isLoading {
                    EmptyStateView(
                        icon: "chart.bar.fill",
                        title: "No quotas",
                        message: canManage
                            ? "No quotas have been set yet. Tap + to set one for a team member."
                            : "You don't have a quota assigned right now.",
                        actionTitle: canManage ? "New Quota" : nil
                    ) { showingNewQuota = true }
                } else {
                    ForEach(viewModel.quotas) { quota in
                        QuotaCardView(
                            quota: quota,
                            canManage: canManage,
                            onUpdateProgress: { newValue in
                                guard let userId = appState.currentUserId else { return }
                                Task { await viewModel.updateProgress(quotaId: quota.id, currentValue: newValue, userId: userId) }
                            },
                            onDelete: {
                                guard let userId = appState.currentUserId else { return }
                                Task { await viewModel.delete(quotaId: quota.id, userId: userId) }
                            }
                        )
                    }
                }
            }
            .padding(16)
        }
        .navigationTitle("Quotas")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if canManage {
                ToolbarItem(placement: .primaryAction) {
                    Button { showingNewQuota = true } label: { Image(systemName: "plus") }
                }
            }
        }
        .task { await load() }
        .refreshable { await load() }
        .sheet(isPresented: $showingNewQuota) {
            NewQuotaSheet(users: appState.users) { targetUserId, label, unit, targetValue, dueDate in
                guard let userId = appState.currentUserId else { return }
                Task {
                    await viewModel.createQuota(
                        targetUserId: targetUserId,
                        label: label,
                        unit: unit,
                        targetValue: targetValue,
                        dueDate: dueDate,
                        userId: userId
                    )
                }
            }
        }
    }

    private func load() async {
        guard let userId = appState.currentUserId else { return }
        await viewModel.load(userId: userId)
    }
}

private struct NewQuotaSheet: View {
    @Environment(\.dismiss) private var dismiss
    let users: [AppUser]
    let onCreate: (String, String, String, Double, Date?) -> Void

    @State private var selectedUserId: String?
    @State private var label: String = ""
    @State private var unit: String = ""
    @State private var targetValueText: String = ""
    @State private var includesDueDate = false
    @State private var dueDate: Date = Date()

    private var targetValue: Double? {
        guard let value = Double(targetValueText), value > 0 else { return nil }
        return value
    }

    private var isValid: Bool {
        selectedUserId != nil
            && !label.trimmingCharacters(in: .whitespaces).isEmpty
            && !unit.trimmingCharacters(in: .whitespaces).isEmpty
            && targetValue != nil
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
                Section("Quota") {
                    TextField("Label (e.g. Fundraising quota)", text: $label)
                    TextField("Unit (e.g. USD, hours)", text: $unit)
                    HStack {
                        Text("Target")
                            .foregroundStyle(.secondary)
                        TextField("0", text: $targetValueText)
                            .keyboardType(.decimalPad)
                    }
                }
                Section("Due Date") {
                    Toggle("Set a due date", isOn: $includesDueDate)
                    if includesDueDate {
                        DatePicker("Due", selection: $dueDate, displayedComponents: .date)
                    }
                }
            }
            .navigationTitle("New Quota")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        guard let selectedUserId, let targetValue else { return }
                        onCreate(
                            selectedUserId,
                            label.trimmingCharacters(in: .whitespacesAndNewlines),
                            unit.trimmingCharacters(in: .whitespacesAndNewlines),
                            targetValue,
                            includesDueDate ? dueDate : nil
                        )
                        dismiss()
                    }
                    .disabled(!isValid)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
