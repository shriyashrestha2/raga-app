import SwiftUI

/// Unified team feed (Roundup → Notifications tab) merging announcements
/// (Update) and reminders (task/RSVP) into one filterable list, matching the
/// Figma prototype's single Notifications feed. The two stay separate
/// backend models/endpoints — this view just blends them for display.
/// Everyone sees the same feed and can mark a task done or RSVP; only
/// Captains/board positions can post (gated by capabilities, same as before).
struct NotificationsSectionView: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject var store: NotificationsStore
    @State private var showingNewReminder = false
    @State private var filter: FeedFilter = .all
    @State private var isEditing = false

    private enum FeedFilter: Hashable {
        case all, tasks, announcements
        case category(CalendarCategory)

        var label: String {
            switch self {
            case .all: return "All"
            case .tasks: return "Tasks"
            case .announcements: return "Announcements"
            case .category(let c): return c.label
            }
        }
    }

    /// Only Captains and board positions (Finance/Production/Logistics/PR) can
    /// create reminders — gated server-side via canCreateReminder in
    /// backend/src/permissions.ts, mirrored here through capabilities.
    private var canCreateReminder: Bool { appState.capabilities?.reminders.canCreate == true }

    private var allItems: [NotificationFeedItem] {
        store.items(withAnnouncements: appState.updates)
    }

    private var filteredItems: [NotificationFeedItem] {
        switch filter {
        case .all: return allItems
        case .tasks: return allItems.filter { if case .reminder(let r) = $0 { return r.type == .task } else { return false } }
        case .announcements: return allItems.filter { if case .announcement = $0 { return true } else { return false } }
        case .category(let c): return allItems.filter { $0.displayCategory == c }
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            if canCreateReminder {
                HStack(spacing: 8) {
                    Button {
                        showingNewReminder = true
                    } label: {
                        Label("Add Notification", systemImage: "plus.circle.fill")
                            .font(.footnote.bold())
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                    }
                    .background(CalendarCategory.finance.color, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                    .shadow(color: CalendarCategory.finance.color.opacity(0.35), radius: 5, y: 2)

                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) { isEditing.toggle() }
                    } label: {
                        Text(isEditing ? "Done" : "Edit")
                            .font(.footnote.bold())
                            .foregroundStyle(isEditing ? Color("AccentColor") : .secondary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .fill(Color(.secondarySystemGroupedBackground))
                            .overlay(
                                RoundedRectangle(cornerRadius: 13, style: .continuous)
                                    .strokeBorder(isEditing ? Color("AccentColor").opacity(0.4) : Color(.separator), lineWidth: 0.75)
                            )
                    )
                    .shadow(color: .black.opacity(0.08), radius: 3, y: 1.5)
                }
                .buttonStyle(.plain)
            }

            if appState.role == .captain, let userId = appState.currentUserId {
                ChoreoReminderWidgetsView(userId: userId)
            }

            filterRow

            if filteredItems.isEmpty && !store.isLoading {
                EmptyStateView(
                    icon: "bell.fill",
                    title: "No notifications",
                    message: canCreateReminder
                        ? "Tap above to post one for the team."
                        : "Check back later for updates from your captains and board.",
                    actionTitle: nil
                ) {}
            } else {
                ForEach(filteredItems) { item in
                    row(for: item)
                }
            }
        }
        .task { await load() }
        .sheet(isPresented: $showingNewReminder) {
            NewReminderSheet(
                lockedCategory: appState.capabilities?.reminders.lockedCategory,
                previewAuthor: appState.currentUser ?? AppUser(
                    id: "preview", name: "You", initials: "ME", role: appState.role,
                    email: nil, phone: nil, year: nil, major: nil, bio: nil,
                    emergencyContactName: nil, emergencyContactPhone: nil
                )
            ) { title, description, date, type, category in
                guard let userId = appState.currentUserId else { return }
                Task { await store.createReminder(title: title, description: description, date: date, type: type, category: category, userId: userId) }
            }
        }
    }

    @ViewBuilder
    private func row(for item: NotificationFeedItem) -> some View {
        let card = NotificationCardView(
            item: item,
            compact: true,
            canDelete: canDelete(item),
            isEditing: isEditing,
            onRsvp: { response in
                guard case .reminder(let reminder) = item, let userId = appState.currentUserId else { return }
                Task { await store.rsvp(id: reminder.id, response: response, userId: userId) }
            },
            onToggleDone: {
                guard case .reminder(let reminder) = item, let userId = appState.currentUserId else { return }
                Task { await store.setDone(id: reminder.id, done: !reminder.doneByMe, userId: userId) }
            },
            onDelete: {
                switch item {
                case .reminder(let reminder):
                    guard let userId = appState.currentUserId else { return }
                    Task { await store.deleteReminder(id: reminder.id, userId: userId) }
                case .announcement(let update):
                    Task { await appState.deleteUpdate(id: update.id) }
                }
            }
        )

        // The swipe-to-dismiss gesture and the edit-mode delete circle both
        // drive the row via drag/tap; disabling the swipe while editing
        // avoids the two fighting over the same row.
        if isEditing {
            card
        } else {
            SwipeToDismissView(onDismiss: { store.dismiss(item) }) { card }
        }
    }

    /// Any board position (Captain/Finance/Production/Logistics/PR) can delete
    /// any notification — reminder or announcement, pinned or not — mirroring
    /// canDeleteAny in backend/src/permissions.ts. Returners/Newbies can't.
    private func canDelete(_ item: NotificationFeedItem) -> Bool {
        appState.capabilities?.notifications.canDeleteAny == true
    }

    private func load() async {
        guard let userId = appState.currentUserId else { return }
        await store.load(userId: userId)
    }

    private var filterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterChip(.all)
                filterChip(.tasks)
                filterChip(.announcements)
                ForEach(CalendarCategory.allCases, id: \.self) { filterChip(.category($0)) }
            }
            .padding(.horizontal, 2)
        }
    }

    private func filterChip(_ option: FeedFilter) -> some View {
        Button {
            filter = option
        } label: {
            HStack(spacing: 5) {
                if case .category(let c) = option {
                    Circle().fill(c.color).frame(width: 7, height: 7)
                }
                Text(option.label)
            }
            .font(.caption.bold())
        }
        .buttonStyle(.bordered)
        .tint(filter == option ? Color("AccentColor") : .gray)
        .buttonBorderShape(.capsule)
        .controlSize(.small)
    }
}

private struct ReminderTypeOption {
    let kind: ReminderKind
    let icon: String
    let description: String
}

private let reminderTypeOptions: [ReminderTypeOption] = [
    .init(kind: .task, icon: "checkmark.circle.fill", description: "Requires action or completion"),
    .init(kind: .rsvp, icon: "calendar.badge.checkmark", description: "Team members RSVP yes or no"),
]

/// Matches the structure/interaction of the Figma "Add Notification" sheet
/// (title/description/date fields, inline-expanding type & category pickers,
/// live preview card) adapted to this app's dark theme and to what a
/// Reminder actually supports server-side — no "pin" toggle, since pinning
/// only exists on Update/announcement, not Reminder.
private struct NewReminderSheet: View {
    @Environment(\.dismiss) private var dismiss
    let lockedCategory: CalendarCategory?
    let previewAuthor: AppUser
    let onCreate: (String, String?, Date, ReminderKind, CalendarCategory) -> Void

    @State private var title = ""
    @State private var description = ""
    @State private var date = Date()
    @State private var type: ReminderKind = .task
    @State private var category: CalendarCategory
    @State private var typeExpanded = false
    @State private var categoryExpanded = false

    init(
        lockedCategory: CalendarCategory?,
        previewAuthor: AppUser,
        onCreate: @escaping (String, String?, Date, ReminderKind, CalendarCategory) -> Void
    ) {
        self.lockedCategory = lockedCategory
        self.previewAuthor = previewAuthor
        self.onCreate = onCreate
        _category = State(initialValue: lockedCategory ?? .practice)
    }

    private var trimmedTitle: String { title.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var isValid: Bool { !trimmedTitle.isEmpty }

    private var selectedTypeOption: ReminderTypeOption {
        reminderTypeOptions.first { $0.kind == type } ?? reminderTypeOptions[0]
    }

    private var previewReminder: ReminderItem {
        ReminderItem(
            id: "preview",
            title: trimmedTitle,
            description: description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : description,
            date: date,
            category: lockedCategory ?? category,
            type: type,
            createdBy: previewAuthor,
            rsvpYes: 0, rsvpNo: 0, myRsvp: nil,
            doneCount: 0, doneByMe: false
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    field(icon: "text.alignleft", label: "Title") {
                        TextField("e.g. Submit costume measurements", text: $title)
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                    }

                    field(icon: "text.alignleft", label: "Description") {
                        TextField("Optional details or context...", text: $description, axis: .vertical)
                            .font(.subheadline.weight(.medium))
                            .lineLimit(3...5)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                    }

                    field(icon: "calendar", label: "Due Date") {
                        DatePicker("", selection: $date, displayedComponents: .date)
                            .labelsHidden()
                            .datePickerStyle(.compact)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                    }

                    typePicker
                    categoryPicker

                    if !trimmedTitle.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            fieldLabel(icon: "eye", text: "Preview")
                            NotificationCardView(item: .reminder(previewReminder), compact: true)
                        }
                    }
                }
                .padding(20)
            }
            .background(Color("AppBackground"))
            .navigationTitle("New Reminder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.secondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        onCreate(trimmedTitle, description.trimmingCharacters(in: .whitespacesAndNewlines), date, type, lockedCategory ?? category)
                        dismiss()
                    }
                    .fontWeight(.bold)
                    .disabled(!isValid)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color("AppBackground"))
    }

    private func fieldLabel(icon: String, text: String) -> some View {
        Label {
            Text(text)
                .font(.system(size: 10, weight: .black))
                .tracking(0.6)
                .textCase(.uppercase)
        } icon: {
            Image(systemName: icon).font(.system(size: 9, weight: .black))
        }
        .foregroundStyle(.secondary)
    }

    @ViewBuilder
    private func field<Content: View>(icon: String, label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            fieldLabel(icon: icon, text: label)
            content()
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color(.secondarySystemGroupedBackground)))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Color(.separator), lineWidth: 0.75))
        }
    }

    private var typePicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            fieldLabel(icon: "tag", text: "Type")
            VStack(spacing: 0) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        typeExpanded.toggle()
                        categoryExpanded = false
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: selectedTypeOption.icon)
                            .foregroundStyle(Color("AccentColor"))
                            .frame(width: 20)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(type.label).font(.subheadline.bold()).foregroundStyle(.primary)
                            Text(selectedTypeOption.description).font(.caption2).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.down")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                            .rotationEffect(.degrees(typeExpanded ? 180 : 0))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if typeExpanded {
                    ForEach(reminderTypeOptions, id: \.kind) { option in
                        Divider().overlay(Color(.separator).opacity(0.5)).padding(.leading, 14)
                        Button {
                            type = option.kind
                            withAnimation(.easeInOut(duration: 0.2)) { typeExpanded = false }
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: option.icon)
                                    .foregroundStyle(type == option.kind ? Color("AccentColor") : .secondary)
                                    .frame(width: 20)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(option.kind.label).font(.subheadline.bold()).foregroundStyle(.primary)
                                    Text(option.description).font(.caption2).foregroundStyle(.secondary)
                                }
                                Spacer()
                                if type == option.kind {
                                    Image(systemName: "checkmark").font(.caption.bold()).foregroundStyle(Color("AccentColor"))
                                }
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color(.secondarySystemGroupedBackground)))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Color(.separator), lineWidth: 0.75))
        }
    }

    private var categoryPicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            fieldLabel(icon: "folder", text: "Category")
            if let lockedCategory {
                HStack(spacing: 10) {
                    Circle().fill(lockedCategory.color).frame(width: 10, height: 10)
                    Text(lockedCategory.label).font(.subheadline.bold()).foregroundStyle(.primary)
                    Spacer()
                    Text("Locked to your role").font(.caption2).foregroundStyle(.secondary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color(.secondarySystemGroupedBackground)))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Color(.separator), lineWidth: 0.75))
            } else {
                VStack(spacing: 0) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            categoryExpanded.toggle()
                            typeExpanded = false
                        }
                    } label: {
                        HStack(spacing: 10) {
                            Circle().fill(category.color).frame(width: 10, height: 10)
                            Text(category.label).font(.subheadline.bold()).foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: "chevron.down")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                                .rotationEffect(.degrees(categoryExpanded ? 180 : 0))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if categoryExpanded {
                        ForEach(CalendarCategory.allCases, id: \.self) { cat in
                            Divider().overlay(Color(.separator).opacity(0.5)).padding(.leading, 14)
                            Button {
                                category = cat
                                withAnimation(.easeInOut(duration: 0.2)) { categoryExpanded = false }
                            } label: {
                                HStack(spacing: 10) {
                                    Circle().fill(cat.color).frame(width: 10, height: 10)
                                    Text(cat.label).font(.subheadline.bold()).foregroundStyle(.primary)
                                    Spacer()
                                    if category == cat {
                                        Image(systemName: "checkmark").font(.caption.bold()).foregroundStyle(Color("AccentColor"))
                                    }
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color(.secondarySystemGroupedBackground)))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Color(.separator), lineWidth: 0.75))
            }
        }
    }
}
