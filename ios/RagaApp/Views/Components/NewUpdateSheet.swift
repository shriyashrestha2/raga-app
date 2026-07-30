import SwiftUI

/// Sheet for posting a new team update/announcement, styled after
/// NewReminderSheet. `audienceRole` (which non-Captain "own channel" this
/// posts under) is auto-scoped server-side from the poster's role — this
/// sheet only exposes content, pinning, and the shared "Visible to" viewer
/// restriction.
struct NewUpdateSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onCreate: (UpdateTag, String, Bool, [Role]) -> Void

    @State private var tag: UpdateTag = .announcement
    @State private var content: String = ""
    @State private var pinned = false
    @State private var visibilitySelection: Set<Role> = []

    private var isValid: Bool {
        !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Update") {
                    Picker("Type", selection: $tag) {
                        ForEach(UpdateTag.allCases, id: \.self) { t in
                            Text(t.label).tag(t)
                        }
                    }
                    TextField("What's the update?", text: $content, axis: .vertical)
                        .lineLimit(3...6)
                    Toggle("Pin to top", isOn: $pinned)
                }

                VisibilityRoleSection(selection: $visibilitySelection)
            }
            .navigationTitle("New Update")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Post") {
                        onCreate(tag, content.trimmingCharacters(in: .whitespacesAndNewlines), pinned, Array(visibilitySelection))
                        dismiss()
                    }
                    .disabled(!isValid)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
