import SwiftUI

/// Fines Tracker tab: team-wide summary numbers and a log-new-fine form.
/// Reuses the existing Fines API/permission model — board roles (per
/// Capabilities.fines.canViewAny) see everyone's fines, Captain/Finance
/// additionally log/edit them, and everyone else sees only their own,
/// server-filtered.
struct FinesTrackerSectionView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var finesViewModel = FinesViewModel()
    @State private var showingNewFine = false

    private var canManageFines: Bool {
        appState.capabilities?.fines.canManageAny == true
    }

    private var totalCollectedCents: Int {
        finesViewModel.fines.filter { $0.status == .paid }.reduce(0) { $0 + $1.amountCents }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Fines Tracker")
                .font(.title3.bold())

            if finesViewModel.fines.isEmpty && !finesViewModel.isLoading {
                EmptyStateView(
                    icon: "dollarsign.circle",
                    title: "No fines yet",
                    message: canManageFines ? "Log a fine below to get started." : "You don't have any fines on record. Nice."
                )
            } else {
                HStack(spacing: 12) {
                    StatTileView(icon: "number", value: "\(finesViewModel.fines.count)", label: "Fines issued")
                    StatTileView(
                        icon: "dollarsign.circle.fill",
                        value: (Double(totalCollectedCents) / 100).formatted(.currency(code: "USD")),
                        label: "Collected"
                    )
                }

                individualFinesSection
            }

            if canManageFines {
                Button {
                    showingNewFine = true
                } label: {
                    Label("Log New Fine", systemImage: "plus.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(Color("AccentColor"))
            }
        }
        .task {
            await loadFines()
        }
        .sheet(isPresented: $showingNewFine) {
            NewFineEntrySheet(users: appState.users) { targetUserId, reason, issuedAt, amountCents, status, dueDate in
                guard let userId = appState.currentUserId else { return }
                Task {
                    await finesViewModel.createFine(
                        targetUserId: targetUserId,
                        amountCents: amountCents,
                        reason: reason,
                        status: status,
                        issuedAt: issuedAt,
                        dueDate: dueDate,
                        userId: userId
                    )
                }
            }
        }
    }

    /// Line-item breakdown of every fine `finesViewModel.fines` currently
    /// holds — reason, amount, status, and who issued it. Board viewers see
    /// everyone's; non-board viewers only ever have their own in that list
    /// (server-filtered), so the heading adjusts rather than the content.
    private var individualFinesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(canManageFines ? "All Fines" : "Your Fines")
                .font(.headline)

            VStack(spacing: 8) {
                ForEach(finesViewModel.fines) { fine in
                    FineCardView(
                        fine: fine,
                        canManage: canManageFines,
                        onSetStatus: { status in
                            guard let userId = appState.currentUserId else { return }
                            Task { await finesViewModel.setStatus(fineId: fine.id, status: status, userId: userId) }
                        },
                        onDelete: {
                            guard let userId = appState.currentUserId else { return }
                            Task { await finesViewModel.delete(fineId: fine.id, userId: userId) }
                        }
                    )
                }
            }
        }
    }

    private func loadFines() async {
        guard let userId = appState.currentUserId else { return }
        await finesViewModel.load(userId: userId)
    }
}

private struct NewFineEntrySheet: View {
    @Environment(\.dismiss) private var dismiss
    let users: [AppUser]
    let onCreate: (String, String, Date, Int, FineStatus, Date?) -> Void

    @State private var selectedUserId: String?
    @State private var reason: String = ""
    @State private var issuedAt: Date = Date()
    @State private var amountText: String = ""
    @State private var status: FineStatus = .unpaid
    @State private var includesDueDate = false
    @State private var dueDate: Date = Date()

    private var amountCents: Int? {
        guard let dollars = Double(amountText), dollars > 0 else { return nil }
        return Int((dollars * 100).rounded())
    }

    private var isValid: Bool {
        selectedUserId != nil && !reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && amountCents != nil
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

                Section("Reason") {
                    TextField("Describe the reason", text: $reason, axis: .vertical)
                        .lineLimit(2...4)
                }

                Section("Date Issued") {
                    DatePicker("Date", selection: $issuedAt, displayedComponents: .date)
                }

                Section("Amount") {
                    HStack {
                        Text("$").foregroundStyle(.secondary)
                        TextField("0.00", text: $amountText)
                            .keyboardType(.decimalPad)
                    }
                }

                Section("Status") {
                    Picker("Status", selection: $status) {
                        ForEach(FineStatus.allCases, id: \.self) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Due Date") {
                    Toggle("Set a due date", isOn: $includesDueDate)
                    if includesDueDate {
                        DatePicker("Due", selection: $dueDate, displayedComponents: .date)
                        Text("They'll get a daily reminder until this date.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("New Fine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Send") {
                        guard let selectedUserId, let amountCents else { return }
                        onCreate(selectedUserId, reason.trimmingCharacters(in: .whitespacesAndNewlines), issuedAt, amountCents, status, includesDueDate ? dueDate : nil)
                        dismiss()
                    }
                    .disabled(!isValid)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
