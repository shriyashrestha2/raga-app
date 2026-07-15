import SwiftUI

/// Captain-only agenda/timeline planning tool — distinct from the Practice
/// tab's RSVP headcount, which stays visible to every role. Reachable only
/// from the Captain's Team-tab menu row.
struct PracticePlannerView: View {
    @EnvironmentObject private var appState: AppState
    @State private var plans: [PracticePlanItem] = []
    @State private var isLoading = false
    @State private var showingNewPlan = false

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if plans.isEmpty && !isLoading {
                    EmptyStateView(
                        icon: "calendar.badge.clock",
                        title: "No practice plans yet",
                        message: "Build an agenda/timeline for an upcoming practice.",
                        actionTitle: "New Plan"
                    ) { showingNewPlan = true }
                } else {
                    ForEach(plans) { plan in
                        NavigationLink { PracticePlanDetailView(plan: plan) } label: {
                            PlanSummaryCard(plan: plan)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(16)
        }
        .navigationTitle("Practice Planner")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showingNewPlan = true } label: { Image(systemName: "plus") }
            }
        }
        .task { await load() }
        .refreshable { await load() }
        .sheet(isPresented: $showingNewPlan) {
            NewPracticePlanSheet { title, date in
                guard let userId = appState.currentUserId else { return }
                Task {
                    try? await APIClient.shared.createPracticePlan(title: title, date: date, userId: userId)
                    await load()
                }
            }
        }
    }

    private func load() async {
        guard let userId = appState.currentUserId else { return }
        isLoading = true
        defer { isLoading = false }
        plans = (try? await APIClient.shared.fetchPracticePlans(userId: userId)) ?? []
    }
}

private struct PlanSummaryCard: View {
    let plan: PracticePlanItem

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(plan.title).font(.subheadline.bold()).foregroundStyle(.primary)
                Text(plan.date, format: .dateTime.month(.abbreviated).day().hour().minute())
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(plan.agendaItems.count) agenda item\(plan.agendaItems.count == 1 ? "" : "s")")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(Color(.separator), lineWidth: 0.5))
    }
}

private struct PracticePlanDetailView: View {
    @EnvironmentObject private var appState: AppState
    @State var plan: PracticePlanItem
    @State private var showingNewItem = false

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 10) {
                ForEach(plan.agendaItems) { PracticeAgendaItemRow(item: $0) }
                if plan.agendaItems.isEmpty {
                    EmptyStateView(icon: "list.bullet", title: "No agenda items yet", message: "Add the first block of this practice's timeline.")
                }
            }
            .padding(16)
        }
        .navigationTitle(plan.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showingNewItem = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $showingNewItem) {
            NewAgendaItemSheet { label, startOffset, duration in
                guard let userId = appState.currentUserId else { return }
                Task {
                    if let created = try? await APIClient.shared.addAgendaItem(
                        planId: plan.id,
                        order: plan.agendaItems.count + 1,
                        startOffsetMin: startOffset,
                        durationMin: duration,
                        label: label,
                        userId: userId
                    ) {
                        plan = PracticePlanItem(id: plan.id, practiceId: plan.practiceId, title: plan.title, date: plan.date, agendaItems: plan.agendaItems + [created])
                    }
                }
            }
        }
    }
}

private struct NewPracticePlanSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var date = Date()
    let onCreate: (String, Date) -> Void

    var body: some View {
        NavigationStack {
            Form {
                TextField("Title", text: $title)
                DatePicker("Date", selection: $date)
            }
            .navigationTitle("New Practice Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        onCreate(title, date)
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

private struct NewAgendaItemSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var label = ""
    @State private var startOffset = 0
    @State private var duration = 15
    let onCreate: (String, Int, Int) -> Void

    var body: some View {
        NavigationStack {
            Form {
                TextField("Label", text: $label)
                Stepper("Starts at +\(startOffset) min", value: $startOffset, in: 0...240, step: 5)
                Stepper("Duration: \(duration) min", value: $duration, in: 5...120, step: 5)
            }
            .navigationTitle("New Agenda Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        onCreate(label, startOffset, duration)
                        dismiss()
                    }
                    .disabled(label.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
}
