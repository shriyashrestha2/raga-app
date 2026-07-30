import SwiftUI
import UIKit

/// Board-only "Draft with AI" helper shared by the Chat composer and the
/// Announcements composer (see Capabilities.aiAssistant.canAccess). Takes
/// rough notes from a board member and returns a finished announcement in
/// the team's voice — or, per the system prompt, a clarifying question when
/// the notes are missing a specific date/time/dollar amount, rather than
/// inventing one. Never sends anything itself: `onUseDraft` hands the
/// finished text back to whichever composer presented this sheet, which the
/// board member still reviews and sends themselves.
struct AIAssistantSheet: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    let onUseDraft: (String) -> Void

    @State private var notes: String = ""
    @State private var response: AIAssistantResponse?
    @State private var isLoading = false
    @State private var errorMessage: String?

    private var canGenerate: Bool {
        !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isLoading
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Rough notes") {
                    TextField("e.g. practice moved to 7-10pm starting aug 10, mon/thurs, message caps if conflict", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section {
                    Button {
                        Task { await generate() }
                    } label: {
                        if isLoading {
                            HStack {
                                Spacer()
                                ProgressView()
                                Spacer()
                            }
                        } else {
                            Text("Generate")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(!canGenerate)
                }

                // On failure the notes above are left exactly as typed —
                // nothing is cleared, so a board member never loses their
                // draft to a flaky request.
                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }

                switch response {
                case .draft(let message):
                    Section("Draft") {
                        Text(message)
                            .textSelection(.enabled)

                        Button {
                            onUseDraft(message)
                            dismiss()
                        } label: {
                            Label("Use This Draft", systemImage: "checkmark.circle.fill")
                        }

                        Button {
                            UIPasteboard.general.string = message
                        } label: {
                            Label("Copy", systemImage: "doc.on.doc")
                        }
                    }
                case .question(let message):
                    Section("Needs a bit more info") {
                        Text(message)
                        Text("Add that to your notes above and generate again.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                case nil:
                    EmptyView()
                }
            }
            .navigationTitle("Draft with AI")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func generate() async {
        guard let userId = appState.currentUserId else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            response = try await APIClient.shared.draftAnnouncement(prompt: notes, userId: userId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
