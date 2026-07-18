import SwiftUI

/// Sheet for adding a calendar event directly from a long-pressed date,
/// styled after RemindersSectionView's NewReminderSheet. Category is locked
/// to the caller's own role for Finance/Production/Logistics/PR (PR owns
/// Social — mirrors the server-side auto-scoping in POST /calendar);
/// Captains pick freely.
struct NewCalendarEventSheet: View {
    @Environment(\.dismiss) private var dismiss
    let role: Role
    let onCreate: (String, String?, Date, CalendarCategory, [Role]) -> Void

    @State private var label: String = ""
    @State private var description: String = ""
    @State private var date: Date
    @State private var category: CalendarCategory
    @State private var visibilitySelection: Set<Role> = []

    init(initialDate: Date, role: Role, onCreate: @escaping (String, String?, Date, CalendarCategory, [Role]) -> Void) {
        self.role = role
        self.onCreate = onCreate
        _date = State(initialValue: initialDate)
        _category = State(initialValue: Self.lockedCategory(for: role) ?? .practice)
    }

    private static func lockedCategory(for role: Role) -> CalendarCategory? {
        switch role {
        case .finance: return .finance
        case .production: return .production
        case .logistics: return .logistics
        case .pr: return .social
        case .captain, .returner, .newbie: return nil
        }
    }

    private var lockedCategory: CalendarCategory? { Self.lockedCategory(for: role) }

    private var isValid: Bool {
        !label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Event") {
                    TextField("Event name", text: $label)
                    TextField("Description (optional)", text: $description, axis: .vertical)
                        .lineLimit(2...4)
                    DatePicker("Date", selection: $date)
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

                VisibilityRoleSection(selection: $visibilitySelection)
            }
            .navigationTitle("New Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        onCreate(
                            label.trimmingCharacters(in: .whitespacesAndNewlines),
                            description.trimmingCharacters(in: .whitespacesAndNewlines),
                            date,
                            lockedCategory ?? category,
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
