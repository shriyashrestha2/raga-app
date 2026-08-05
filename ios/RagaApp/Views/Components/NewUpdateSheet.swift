import SwiftUI

/// Sheet for posting a new team update/announcement, styled after
/// NewReminderSheet. `audienceRole` (which non-Captain "own channel" this
/// posts under) is auto-scoped server-side from the poster's role — this
/// sheet exposes content, the shared "Visible to" viewer restriction, and
/// (board roles only) a "Draft with AI" helper that fills `content` from
/// rough notes — see AIAssistantSheet.
struct NewUpdateSheet: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    let onCreate: (UpdateTag, String, [Role]) -> Void

    @State private var tag: UpdateTag = .announcement
    @State private var content: String = ""
    @State private var visibilitySelection: Set<Role> = []
    @State private var showAIAssistant = false

    private var isValid: Bool {
        !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Update") {
                    Picker("Type", selection: $tag) {
                        ForEach(UpdateTag.userCreatable, id: \.self) { t in
                            Text(t.label).tag(t)
                        }
                    }
                    TextField("What's the update?", text: $content, axis: .vertical)
                        .lineLimit(3...6)

                    if appState.capabilities?.aiAssistant.canAccess == true {
                        Button {
                            showAIAssistant = true
                        } label: {
                            Label("Draft with AI", systemImage: "sparkles")
                        }
                    }
                }

                VisibilityRoleSection(selection: $visibilitySelection)
            }
            .navigationTitle("New Update")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Post") {
                        onCreate(tag, content.trimmingCharacters(in: .whitespacesAndNewlines), Array(visibilitySelection))
                        dismiss()
                    }
                    .disabled(!isValid)
                }
            }
            .sheet(isPresented: $showAIAssistant) {
                AIAssistantSheet { message in
                    content = message
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
