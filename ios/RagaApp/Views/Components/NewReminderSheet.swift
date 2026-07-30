import SwiftUI

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
/// live preview card) adapted to this app's theme and to what a Reminder
/// actually supports server-side — no "pin" toggle, since pinning only
/// exists on Update/announcement, not Reminder. Triggered from the
/// calendar's "+" button in MiniCalendarView (the old separate "Add
/// Notification" button was folded into that single entry point).
struct NewReminderSheet: View {
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
            .navigationTitle("New Notification")
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
