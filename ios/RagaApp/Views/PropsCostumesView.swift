import SwiftUI

/// Props & Costumes screen. Renders one of four modes based on
/// `appState.capabilities?.propsCostumes.mode` (server-derived, mirrors
/// backend/src/permissions.ts's propsCostumesAccess):
///   FULL                  — Captain/Production: full item list + create/edit/assign.
///   BUDGET_ONLY            — Finance: aggregate budget summary only.
///   OWN_ASSIGNMENTS_ONLY   — Dancer/Newbie: read-only list of the viewer's own tasks.
///   NONE / missing          — Logistics (or capabilities not yet loaded): restricted state.
struct PropsCostumesView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = PropsCostumesViewModel()
    @State private var showingNewItem = false

    private var mode: String {
        appState.capabilities?.propsCostumes.mode ?? "NONE"
    }

    var body: some View {
        ScrollView {
            Group {
                switch mode {
                case "FULL":
                    fullContent
                case "BUDGET_ONLY":
                    budgetContent
                case "OWN_ASSIGNMENTS_ONLY":
                    ownAssignmentsContent
                default:
                    EmptyStateView.restrictedAccess()
                }
            }
            .padding(16)
        }
        .navigationTitle("Props & Costumes")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if mode == "FULL" {
                ToolbarItem(placement: .primaryAction) {
                    Button { showingNewItem = true } label: { Image(systemName: "plus") }
                }
            }
        }
        .task { await load() }
        .refreshable { await load() }
        .sheet(isPresented: $showingNewItem) {
            NewPropCostumeItemSheet { name, category in
                guard let userId = appState.currentUserId else { return }
                Task { await viewModel.createItem(name: name, category: category, userId: userId) }
            }
        }
    }

    private func load() async {
        guard let userId = appState.currentUserId else { return }
        await viewModel.load(userId: userId, mode: mode)
    }

    // MARK: FULL — Captain/Production

    @ViewBuilder
    private var fullContent: some View {
        if viewModel.items.isEmpty && !viewModel.isLoading {
            EmptyStateView(
                icon: "tshirt",
                title: "No props or costumes yet",
                message: "Add an item to start tracking costumes, rentals, and assignments.",
                actionTitle: "New Item"
            ) { showingNewItem = true }
        } else {
            LazyVStack(spacing: 12) {
                ForEach(viewModel.items) { item in
                    NavigationLink {
                        PropCostumeDetailView(item: item, viewModel: viewModel)
                    } label: {
                        PropCostumeCardView(item: item)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: BUDGET_ONLY — Finance

    @ViewBuilder
    private var budgetContent: some View {
        if let budget = viewModel.budget {
            VStack(spacing: 12) {
                BudgetSummaryCard(budget: budget)
                if budget.items.isEmpty {
                    EmptyStateView(
                        icon: "tshirt",
                        title: "No rental costs yet",
                        message: "Costs will appear here once Captains or Production add items."
                    )
                } else {
                    LazyVStack(spacing: 10) {
                        ForEach(budget.items) { line in
                            BudgetLineRow(line: line)
                        }
                    }
                }
            }
        } else if !viewModel.isLoading {
            EmptyStateView(
                icon: "tshirt",
                title: "No budget data",
                message: "Pull to refresh to load the props & costumes budget."
            )
        }
    }

    // MARK: OWN_ASSIGNMENTS_ONLY — Dancer/Newbie

    @ViewBuilder
    private var ownAssignmentsContent: some View {
        if viewModel.items.isEmpty && !viewModel.isLoading {
            EmptyStateView(
                icon: "tshirt",
                title: "No assignments yet",
                message: "Props/costume tasks assigned to you will show up here."
            )
        } else {
            LazyVStack(spacing: 12) {
                ForEach(viewModel.items) { item in
                    PropCostumeCardView(item: item)
                }
            }
        }
    }
}

private struct BudgetSummaryCard: View {
    let budget: PropsCostumesBudget

    private func formatted(_ cents: Int) -> String {
        (Double(cents) / 100).formatted(.currency(code: "USD"))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Budget Summary")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Total Budget").font(.caption2).foregroundStyle(.secondary)
                    Text(formatted(budget.totalBudgetCents)).font(.title3.bold())
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Spent").font(.caption2).foregroundStyle(.secondary)
                    Text(formatted(budget.totalSpentCents)).font(.title3.bold()).foregroundStyle(Color("AccentColor"))
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(Color(.separator), lineWidth: 0.5))
    }
}

private struct BudgetLineRow: View {
    let line: BudgetLineItem

    var body: some View {
        HStack {
            Text(line.name).font(.subheadline)
            Spacer()
            if let cents = line.rentalCostCents {
                Text((Double(cents) / 100).formatted(.currency(code: "USD")))
                    .font(.subheadline.bold())
            } else {
                Text("—").font(.subheadline).foregroundStyle(.tertiary)
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Color(.separator), lineWidth: 0.5))
    }
}

private struct NewPropCostumeItemSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var category: PropCostumeCategoryType = .prop
    let onCreate: (String, PropCostumeCategoryType) -> Void

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $name)
                Picker("Category", selection: $category) {
                    Text("Prop").tag(PropCostumeCategoryType.prop)
                    Text("Costume").tag(PropCostumeCategoryType.costume)
                }
                .pickerStyle(.segmented)
            }
            .navigationTitle("New Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        onCreate(name, category)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

private struct PropCostumeDetailView: View {
    @EnvironmentObject private var appState: AppState
    let item: PropCostumeItemModel
    @ObservedObject var viewModel: PropsCostumesViewModel
    @State private var showingAssign = false

    private var current: PropCostumeItemModel {
        viewModel.items.first(where: { $0.id == item.id }) ?? item
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                PropCostumeCardView(item: current)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Status").font(.caption.bold()).foregroundStyle(.secondary)
                    Picker("Status", selection: Binding(
                        get: { current.status },
                        set: { newStatus in
                            guard let userId = appState.currentUserId else { return }
                            Task { await viewModel.updateStatus(itemId: item.id, status: newStatus, userId: userId) }
                        }
                    )) {
                        ForEach(PropCostumeStatusType.allCases, id: \.self) { status in
                            Text(status.label).tag(status)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(Color(.separator), lineWidth: 0.5))

                Button {
                    showingAssign = true
                } label: {
                    Label("Assign Member", systemImage: "person.badge.plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color("AccentColor"))
            }
            .padding(16)
        }
        .navigationTitle(item.name)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingAssign) {
            AssignMemberSheet(users: appState.users) { targetUserId, size, task in
                guard let userId = appState.currentUserId else { return }
                Task { await viewModel.assign(itemId: item.id, targetUserId: targetUserId, size: size, task: task, userId: userId) }
            }
        }
    }
}

private struct AssignMemberSheet: View {
    @Environment(\.dismiss) private var dismiss
    let users: [AppUser]
    @State private var selectedUserId: String?
    @State private var size = ""
    @State private var task = ""
    let onAssign: (String, String?, String?) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Picker("Member", selection: $selectedUserId) {
                    Text("Select a member").tag(String?.none)
                    ForEach(users) { user in
                        Text(user.name).tag(Optional(user.id))
                    }
                }
                TextField("Size (optional)", text: $size)
                TextField("Task (optional)", text: $task)
            }
            .navigationTitle("Assign Member")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Assign") {
                        guard let selectedUserId else { return }
                        onAssign(selectedUserId, size.isEmpty ? nil : size, task.isEmpty ? nil : task)
                        dismiss()
                    }
                    .disabled(selectedUserId == nil)
                }
            }
        }
        .presentationDetents([.medium])
    }
}
