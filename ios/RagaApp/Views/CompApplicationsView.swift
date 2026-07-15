import SwiftUI

/// Captain/Logistics-only competition-application tracker. The nav entry is
/// hidden from other roles by a separate pass, but this view defensively
/// re-checks `capabilities.compApplications.canAccess` itself in case it's
/// ever reached directly (deep link, stale nav state, etc).
struct CompApplicationsView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = CompApplicationsViewModel()
    @State private var showingNewApplication = false
    @State private var selectedApplication: CompApplicationItem?

    private var canAccess: Bool {
        appState.capabilities?.compApplications.canAccess ?? false
    }

    var body: some View {
        Group {
            if !canAccess {
                ScrollView {
                    EmptyStateView.restrictedAccess()
                        .padding(16)
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        if viewModel.applications.isEmpty && !viewModel.isLoading {
                            EmptyStateView(
                                icon: "doc.text.magnifyingglass",
                                title: "No comp applications yet",
                                message: "Track competition applications, deadlines, and packet status here.",
                                actionTitle: "New Application"
                            ) { showingNewApplication = true }
                        } else {
                            ForEach(viewModel.applications) { application in
                                Button {
                                    selectedApplication = application
                                } label: {
                                    CompApplicationCardView(application: application)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(16)
                }
                .refreshable { await load() }
            }
        }
        .navigationTitle("Comp Applications")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if canAccess {
                ToolbarItem(placement: .primaryAction) {
                    Button { showingNewApplication = true } label: { Image(systemName: "plus") }
                }
            }
        }
        .task { if canAccess { await load() } }
        .alert("Error", isPresented: Binding(get: { viewModel.errorMessage != nil }, set: { if !$0 { viewModel.errorMessage = nil } })) {
            Button("OK", role: .cancel) { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .sheet(isPresented: $showingNewApplication) {
            NewCompApplicationSheet(members: appState.users) { competitionName, deadline, assignedToId in
                guard let userId = appState.currentUserId else { return }
                Task { await viewModel.create(competitionName: competitionName, deadline: deadline, assignedToId: assignedToId, userId: userId) }
            }
        }
        .sheet(item: $selectedApplication) { application in
            CompApplicationDetailSheet(application: application, members: appState.users) { competitionName, deadline, status, packetUrl, notes, assignedToId in
                guard let userId = appState.currentUserId else { return }
                Task {
                    await viewModel.update(
                        id: application.id,
                        competitionName: competitionName,
                        deadline: deadline,
                        status: status,
                        packetUrl: packetUrl,
                        notes: notes,
                        assignedToId: .some(assignedToId),
                        userId: userId
                    )
                }
            } onDelete: {
                guard let userId = appState.currentUserId else { return }
                Task { await viewModel.delete(id: application.id, userId: userId) }
            }
        }
    }

    private func load() async {
        guard let userId = appState.currentUserId else { return }
        await viewModel.load(userId: userId)
    }
}

private struct NewCompApplicationSheet: View {
    @Environment(\.dismiss) private var dismiss
    let members: [AppUser]
    let onCreate: (String, Date, String?) -> Void

    @State private var competitionName = ""
    @State private var deadline = Date()
    @State private var assignedToId: String?

    var body: some View {
        NavigationStack {
            Form {
                TextField("Competition Name", text: $competitionName)
                DatePicker("Deadline", selection: $deadline, displayedComponents: [.date])
                Picker("Assign To", selection: $assignedToId) {
                    Text("Unassigned").tag(String?.none)
                    ForEach(members) { member in
                        Text(member.name).tag(String?.some(member.id))
                    }
                }
            }
            .navigationTitle("New Application")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        onCreate(competitionName, deadline, assignedToId)
                        dismiss()
                    }
                    .disabled(competitionName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

private struct CompApplicationDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    let application: CompApplicationItem
    let members: [AppUser]
    let onSave: (String, Date, CompApplicationStatusType, String, String, String?) -> Void
    let onDelete: () -> Void

    @State private var competitionName: String
    @State private var deadline: Date
    @State private var status: CompApplicationStatusType
    @State private var packetUrl: String
    @State private var notes: String
    @State private var assignedToId: String?
    @State private var showingDeleteConfirm = false

    init(
        application: CompApplicationItem,
        members: [AppUser],
        onSave: @escaping (String, Date, CompApplicationStatusType, String, String, String?) -> Void,
        onDelete: @escaping () -> Void
    ) {
        self.application = application
        self.members = members
        self.onSave = onSave
        self.onDelete = onDelete
        _competitionName = State(initialValue: application.competitionName)
        _deadline = State(initialValue: application.deadline)
        _status = State(initialValue: application.status)
        _packetUrl = State(initialValue: application.packetUrl ?? "")
        _notes = State(initialValue: application.notes ?? "")
        _assignedToId = State(initialValue: application.assignedTo?.id)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Competition") {
                    TextField("Competition Name", text: $competitionName)
                    DatePicker("Deadline", selection: $deadline, displayedComponents: [.date])
                }
                Section("Status") {
                    Picker("Status", selection: $status) {
                        ForEach(CompApplicationStatusType.allCases, id: \.self) { option in
                            Text(option.label).tag(option)
                        }
                    }
                }
                Section("Assignment") {
                    Picker("Assign To", selection: $assignedToId) {
                        Text("Unassigned").tag(String?.none)
                        ForEach(members) { member in
                            Text(member.name).tag(String?.some(member.id))
                        }
                    }
                }
                Section("Packet") {
                    TextField("Packet URL", text: $packetUrl)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }
                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 80)
                }
                Section {
                    Button("Delete Application", role: .destructive) {
                        showingDeleteConfirm = true
                    }
                }
            }
            .navigationTitle("Edit Application")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(competitionName, deadline, status, packetUrl, notes, assignedToId)
                        dismiss()
                    }
                    .disabled(competitionName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .confirmationDialog("Delete this application?", isPresented: $showingDeleteConfirm, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    onDelete()
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            }
        }
        .presentationDetents([.large])
    }
}
