import SwiftUI

/// Fines Tracker tab: team-wide summary numbers, a per-offense breakdown
/// chart, a log-new-fine form, and the editable fine schedule. Reuses the
/// existing Fines API/permission model — board roles (per
/// Capabilities.fines.canViewAny) see everyone's fines, Captain/Finance
/// additionally log/edit them, and everyone else sees only their own,
/// server-filtered.
struct FinesTrackerSectionView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var finesViewModel = FinesViewModel()
    @StateObject private var scheduleViewModel = FineScheduleViewModel()
    @State private var showingNewFine = false
    @State private var showingScheduleEditor = false

    private var canManageFines: Bool {
        appState.capabilities?.fines.canManageAny == true
    }

    private var canManageSchedule: Bool {
        appState.capabilities?.fineSchedule.canManageAny == true
    }

    private var totalCollectedCents: Int {
        finesViewModel.fines.filter { $0.status == .paid }.reduce(0) { $0 + $1.amountCents }
    }

    private var byOffense: [FineOffenseSlice] {
        let grouped = Dictionary(grouping: finesViewModel.fines, by: \.reason)
        let slices: [FineOffenseSlice] = grouped.map { offense, fines in
            FineOffenseSlice(offense: offense, count: fines.count)
        }
        return slices.sorted { $0.count > $1.count }
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

                FinesByOffenseChart(slices: byOffense)
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

            fineScheduleSection
        }
        .task {
            await loadFines()
            await loadSchedule()
        }
        .sheet(isPresented: $showingNewFine) {
            NewFineEntrySheet(users: appState.users, schedule: scheduleViewModel.entries) { targetUserId, reason, issuedAt, amountCents, status, dueDate in
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

    private var fineScheduleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Fine Schedule")
                    .font(.headline)
                Spacer()
                if canManageSchedule {
                    Button {
                        showingScheduleEditor = true
                    } label: {
                        Label("Edit", systemImage: "pencil")
                            .font(.caption.bold())
                    }
                }
            }

            VStack(spacing: 8) {
                ForEach(scheduleViewModel.entries) { entry in
                    FineScheduleRowView(entry: entry)
                }
            }
        }
        .sheet(isPresented: $showingScheduleEditor) {
            FineScheduleEditorView(viewModel: scheduleViewModel)
        }
    }

    private func loadFines() async {
        guard let userId = appState.currentUserId else { return }
        await finesViewModel.load(userId: userId)
    }

    private func loadSchedule() async {
        guard let userId = appState.currentUserId else { return }
        await scheduleViewModel.load(userId: userId)
    }
}

private struct NewFineEntrySheet: View {
    @Environment(\.dismiss) private var dismiss
    let users: [AppUser]
    let schedule: [FineScheduleEntry]
    let onCreate: (String, String, Date, Int, FineStatus, Date?) -> Void

    @State private var selectedUserId: String?
    @State private var selectedOffenseId: String?
    @State private var customReason: String = ""
    @State private var issuedAt: Date = Date()
    @State private var amountText: String = ""
    @State private var status: FineStatus = .unpaid
    @State private var includesDueDate = false
    @State private var dueDate: Date = Date()

    private var selectedEntry: FineScheduleEntry? {
        schedule.first(where: { $0.id == selectedOffenseId })
    }

    private var reason: String {
        if let selectedEntry {
            return selectedEntry.offense
        }
        return customReason.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var amountCents: Int? {
        guard let dollars = Double(amountText), dollars > 0 else { return nil }
        return Int((dollars * 100).rounded())
    }

    private var isValid: Bool {
        selectedUserId != nil && !reason.isEmpty && amountCents != nil
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
                    Picker("Offense", selection: $selectedOffenseId) {
                        Text("Custom reason").tag(String?.none)
                        ForEach(schedule) { entry in
                            Text(entry.offense).tag(Optional(entry.id))
                        }
                    }
                    .onChange(of: selectedOffenseId) { _, newValue in
                        guard let entry = schedule.first(where: { $0.id == newValue }) else {
                            amountText = ""
                            return
                        }
                        if let cents = entry.amountCents {
                            amountText = String(format: "%.2f", Double(cents) / 100.0)
                        } else {
                            amountText = ""
                        }
                    }

                    if selectedOffenseId == nil {
                        TextField("Describe the reason", text: $customReason, axis: .vertical)
                            .lineLimit(2...4)
                    } else if let selectedEntry, selectedEntry.isVariable, let description = selectedEntry.description {
                        Text(description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
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
                        onCreate(selectedUserId, reason, issuedAt, amountCents, status, includesDueDate ? dueDate : nil)
                        dismiss()
                    }
                    .disabled(!isValid)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
