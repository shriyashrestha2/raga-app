import SwiftUI

/// Personal reminders section of the Roundup page. Every role organizes
/// their own reminders into named topics, each rendered as its own bulleted
/// list; a reminder can optionally also be added to the shared team
/// calendar (see AppState.loadCalendarEvents(), called after any create that
/// opts in).
struct RemindersSectionView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = RemindersViewModel()
    @State private var showingNewTopic = false
    @State private var addReminderTopic: ReminderTopic?

    var body: some View {
        VStack(spacing: 12) {
            if viewModel.topics.isEmpty && !viewModel.isLoading {
                EmptyStateView(
                    icon: "list.bullet.rectangle",
                    title: "No reminder topics yet",
                    message: "Group your reminders by topic — tap below to create your first one.",
                    actionTitle: "New Topic"
                ) { showingNewTopic = true }
            } else {
                ForEach(viewModel.topics) { topic in
                    ReminderTopicCardView(
                        topic: topic,
                        onAddReminder: { addReminderTopic = topic },
                        onDeleteTopic: {
                            guard let userId = appState.currentUserId else { return }
                            Task { await viewModel.deleteTopic(topicId: topic.id, userId: userId) }
                        },
                        onDeleteReminder: { reminderId in
                            guard let userId = appState.currentUserId else { return }
                            Task { await viewModel.deleteReminder(topicId: topic.id, reminderId: reminderId, userId: userId) }
                        }
                    )
                }

                Button {
                    showingNewTopic = true
                } label: {
                    Label("New Topic", systemImage: "plus.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(Color("AccentColor"))
            }
        }
        .task { await load() }
        .sheet(isPresented: $showingNewTopic) {
            NewTopicSheet { name in
                guard let userId = appState.currentUserId else { return }
                Task { await viewModel.addTopic(name: name, userId: userId) }
            }
        }
        .sheet(item: $addReminderTopic) { topic in
            NewReminderSheet(topicName: topic.name) { title, description, date, addToCalendar, visibleToRoles in
                guard let userId = appState.currentUserId else { return }
                Task {
                    let addedToCalendar = await viewModel.addReminder(
                        topicId: topic.id,
                        title: title,
                        description: description,
                        date: date,
                        addToCalendar: addToCalendar,
                        visibleToRoles: visibleToRoles,
                        userId: userId
                    )
                    if addedToCalendar {
                        await appState.loadCalendarEvents()
                    }
                }
            }
        }
    }

    private func load() async {
        guard let userId = appState.currentUserId else { return }
        await viewModel.load(userId: userId)
    }
}

private struct ReminderTopicCardView: View {
    let topic: ReminderTopic
    let onAddReminder: () -> Void
    let onDeleteTopic: () -> Void
    let onDeleteReminder: (String) -> Void

    @State private var showDeleteConfirm = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(topic.name)
                    .font(.subheadline.bold())
                Spacer()
                Button(action: onAddReminder) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(Color("AccentColor"))
                }
                Menu {
                    Button(role: .destructive) { showDeleteConfirm = true } label: {
                        Label("Delete Topic", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(.secondary)
                }
            }

            if topic.reminders.isEmpty {
                Text("No reminders yet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(topic.reminders) { reminder in
                        ReminderRowView(reminder: reminder)
                            .contextMenu {
                                Button(role: .destructive) { onDeleteReminder(reminder.id) } label: {
                                    Label("Delete Reminder", systemImage: "trash")
                                }
                            }
                    }
                }
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(Color(.separator), lineWidth: 0.5))
        .confirmationDialog("Delete this topic and all its reminders?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive, action: onDeleteTopic)
            Button("Cancel", role: .cancel) {}
        }
    }
}

private struct ReminderRowView: View {
    let reminder: ReminderItem

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(Color("AccentColor"))
                .frame(width: 6, height: 6)
                .padding(.top, 6)

            VStack(alignment: .leading, spacing: 2) {
                Text(reminder.title)
                    .font(.subheadline.weight(.medium))
                if let description = reminder.description, !description.isEmpty {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 6) {
                    Text(reminder.date.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    if reminder.addedToCalendar {
                        Label("On calendar", systemImage: "calendar")
                            .font(.caption2.bold())
                            .foregroundStyle(.teal)
                            .labelStyle(.iconOnly)
                    }
                }
            }
            Spacer(minLength: 0)
        }
    }
}

private struct NewTopicSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onCreate: (String) -> Void

    @State private var name: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Topic") {
                    TextField("e.g. Costumes, Fundraising", text: $name)
                }
            }
            .navigationTitle("New Topic")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        onCreate(name.trimmingCharacters(in: .whitespacesAndNewlines))
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

private struct NewReminderSheet: View {
    @Environment(\.dismiss) private var dismiss
    let topicName: String
    let onCreate: (String, String?, Date, Bool, [Role]) -> Void

    @State private var title: String = ""
    @State private var description: String = ""
    @State private var date: Date = Date()
    @State private var addToCalendar = false
    @State private var visibilitySelection: Set<Role> = []

    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(topicName) {
                    TextField("Reminder name", text: $title)
                    TextField("Description (optional)", text: $description, axis: .vertical)
                        .lineLimit(2...4)
                    DatePicker("Date", selection: $date)
                }
                Section {
                    Toggle("Add to team calendar", isOn: $addToCalendar)
                } footer: {
                    Text("If enabled, this reminder also appears on the shared team calendar.")
                }
                VisibilityRoleSection(selection: $visibilitySelection)
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
                            addToCalendar,
                            Array(visibilitySelection)
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
