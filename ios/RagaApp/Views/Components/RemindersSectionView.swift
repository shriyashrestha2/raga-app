import SwiftUI

/// Shared team reminders (Roundup tab) — everyone sees the same list,
/// filterable by category; category color mirrors MiniCalendarView's
/// CalendarCategory.color for visual consistency with the team calendar.
/// Only Captains/board positions can create (gated by
/// appState.capabilities.reminders.canCreate — see backend/src/permissions.ts
/// canCreateReminder); everyone can RSVP or mark a task done.
struct RemindersSectionView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = RemindersViewModel()
    @State private var showingNewReminder = false
    @State private var showingNewUpdate = false

    private var canCreate: Bool { appState.capabilities?.reminders.canCreate == true }

    private var pinnedUpdates: [UpdateItem] { appState.updates.filter(\.pinned) }
    private var recentUpdates: [UpdateItem] { appState.updates.filter { !$0.pinned }.prefix(3).map { $0 } }

    private var canPostUpdate: Bool {
        appState.capabilities?.announcements.canPostTeamWide == true || appState.capabilities?.announcements.ownChannelRole != nil
    }

    var body: some View {
        VStack(spacing: 12) {
            if appState.role == .captain, let userId = appState.currentUserId {
                ChoreoReminderWidgetsView(userId: userId)
            }

            if canPostUpdate {
                Button {
                    showingNewUpdate = true
                } label: {
                    Label("New Update", systemImage: "plus.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color("AccentColor"))
            }

            ForEach(pinnedUpdates) { UpdateCardView(update: $0) }
            ForEach(recentUpdates) { UpdateCardView(update: $0) }

            if !pinnedUpdates.isEmpty || !recentUpdates.isEmpty {
                HStack {
                    Rectangle().fill(Color(.separator)).frame(height: 0.5)
                    Text("REMINDERS")
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)
                        .fixedSize()
                    Rectangle().fill(Color(.separator)).frame(height: 0.5)
                }
                .padding(.top, 4)
            }

            categoryFilterRow

            if viewModel.reminders.isEmpty && !viewModel.isLoading {
                EmptyStateView(
                    icon: "checklist",
                    title: "No reminders",
                    message: canCreate
                        ? "Tap below to post one for the team."
                        : "Check back later for reminders from your captains and board.",
                    actionTitle: canCreate ? "New Reminder" : nil
                ) { showingNewReminder = true }
            } else {
                ForEach(viewModel.reminders) { reminder in
                    ReminderCardView(
                        reminder: reminder,
                        canDelete: appState.role == .captain || reminder.createdBy.id == appState.currentUserId,
                        onRsvp: { response in
                            guard let userId = appState.currentUserId else { return }
                            Task { await viewModel.rsvp(id: reminder.id, response: response, userId: userId) }
                        },
                        onToggleDone: {
                            guard let userId = appState.currentUserId else { return }
                            Task { await viewModel.setDone(id: reminder.id, done: !reminder.doneByMe, userId: userId) }
                        },
                        onDelete: {
                            guard let userId = appState.currentUserId else { return }
                            Task { await viewModel.deleteReminder(id: reminder.id, userId: userId) }
                        }
                    )
                }

                if canCreate {
                    Button {
                        showingNewReminder = true
                    } label: {
                        Label("New Reminder", systemImage: "plus.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color("AccentColor"))
                }
            }
        }
        .task { await load() }
        .sheet(isPresented: $showingNewReminder) {
            NewReminderSheet(lockedCategory: appState.capabilities?.reminders.lockedCategory) { title, description, date, type, category in
                guard let userId = appState.currentUserId else { return }
                Task { await viewModel.createReminder(title: title, description: description, date: date, type: type, category: category, userId: userId) }
            }
        }
        .sheet(isPresented: $showingNewUpdate) {
            NewUpdateSheet { tag, content, pinned, visibleToRoles in
                Task { await appState.createUpdate(tag: tag, content: content, pinned: pinned, visibleToRoles: visibleToRoles) }
            }
        }
    }

    private func load() async {
        guard let userId = appState.currentUserId else { return }
        await viewModel.load(userId: userId)
    }

    private var categoryFilterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterChip(label: "All", category: nil)
                ForEach(CalendarCategory.allCases, id: \.self) { category in
                    filterChip(label: category.label, category: category)
                }
            }
            .padding(.horizontal, 2)
        }
    }

    private func filterChip(label: String, category: CalendarCategory?) -> some View {
        Button {
            viewModel.selectedCategory = category
            Task { await load() }
        } label: {
            HStack(spacing: 5) {
                if let category {
                    Circle().fill(category.color).frame(width: 7, height: 7)
                }
                Text(label)
            }
            .font(.caption.bold())
        }
        .buttonStyle(.bordered)
        .tint(viewModel.selectedCategory == category ? Color("AccentColor") : .gray)
        .buttonBorderShape(.capsule)
        .controlSize(.small)
    }
}

private struct ReminderCardView: View {
    let reminder: ReminderItem
    let canDelete: Bool
    let onRsvp: (RsvpResponse) -> Void
    let onToggleDone: () -> Void
    let onDelete: () -> Void

    @State private var showDeleteConfirm = false

    var body: some View {
        HStack(spacing: 0) {
            Rectangle().fill(reminder.category.color).frame(width: 4)

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(reminder.category.label.uppercased())
                                .font(.caption2.bold())
                                .foregroundStyle(reminder.category.color)
                            Text("·")
                                .foregroundStyle(.tertiary)
                            Text(reminder.date, format: .dateTime.month(.abbreviated).day())
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Text(reminder.title)
                            .font(.subheadline.bold())
                        if let description = reminder.description, !description.isEmpty {
                            Text(description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Text("from \(reminder.createdBy.name)")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    Spacer(minLength: 8)
                    if canDelete {
                        Menu {
                            Button(role: .destructive) { showDeleteConfirm = true } label: {
                                Label("Delete Reminder", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Divider()

                switch reminder.type {
                case .rsvp:
                    HStack {
                        Text("\(reminder.rsvpYes) yes · \(reminder.rsvpNo) no")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        HStack(spacing: 8) {
                            Button { onRsvp(.yes) } label: { Label("Yes", systemImage: "checkmark") }
                                .tint(reminder.myRsvp == .yes ? .green : .gray)
                            Button { onRsvp(.no) } label: { Label("No", systemImage: "xmark") }
                                .tint(reminder.myRsvp == .no ? Color("AccentColor") : .gray)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                case .task:
                    HStack {
                        Text("\(reminder.doneCount) done")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button {
                            onToggleDone()
                        } label: {
                            Label(reminder.doneByMe ? "Done" : "Mark done", systemImage: reminder.doneByMe ? "checkmark.circle.fill" : "circle")
                        }
                        .buttonStyle(.bordered)
                        .tint(reminder.doneByMe ? .green : .gray)
                        .controlSize(.small)
                    }
                }
            }
            .padding(14)
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(Color(.separator), lineWidth: 0.5))
        .confirmationDialog("Delete this reminder?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive, action: onDelete)
            Button("Cancel", role: .cancel) {}
        }
    }
}

private struct NewReminderSheet: View {
    @Environment(\.dismiss) private var dismiss
    let lockedCategory: CalendarCategory?
    let onCreate: (String, String?, Date, ReminderKind, CalendarCategory) -> Void

    @State private var title = ""
    @State private var description = ""
    @State private var date = Date()
    @State private var type: ReminderKind = .task
    @State private var category: CalendarCategory

    init(lockedCategory: CalendarCategory?, onCreate: @escaping (String, String?, Date, ReminderKind, CalendarCategory) -> Void) {
        self.lockedCategory = lockedCategory
        self.onCreate = onCreate
        _category = State(initialValue: lockedCategory ?? .practice)
    }

    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Reminder") {
                    TextField("Title", text: $title)
                    TextField("Description (optional)", text: $description, axis: .vertical)
                        .lineLimit(2...4)
                    DatePicker("Date", selection: $date)
                    Picker("Type", selection: $type) {
                        ForEach(ReminderKind.allCases, id: \.self) { Text($0.label).tag($0) }
                    }
                }

                Section("Category") {
                    if let lockedCategory {
                        HStack(spacing: 8) {
                            Circle().fill(lockedCategory.color).frame(width: 8, height: 8)
                            Text(lockedCategory.label)
                        }
                    } else {
                        Picker("Category", selection: $category) {
                            ForEach(CalendarCategory.allCases, id: \.self) { cat in
                                Text(cat.label).tag(cat)
                            }
                        }
                    }
                }
            }
            .navigationTitle("New Reminder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        onCreate(
                            title.trimmingCharacters(in: .whitespacesAndNewlines),
                            description.trimmingCharacters(in: .whitespacesAndNewlines),
                            date,
                            type,
                            lockedCategory ?? category
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
