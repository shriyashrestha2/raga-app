import SwiftUI

/// Add/edit/remove screen for the fine schedule (Finance chairs + Captains
/// only — gated by Capabilities.fineSchedule, enforced server-side too).
/// Presented as a sheet from the Fines Tracker section of the Finance tab.
struct FineScheduleEditorView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: FineScheduleViewModel
    @State private var showingNewEntry = false
    @State private var editingEntry: FineScheduleEntry?

    var body: some View {
        NavigationStack {
            List {
                ForEach(viewModel.entries) { entry in
                    Button {
                        editingEntry = entry
                    } label: {
                        FineScheduleRowView(entry: entry)
                    }
                    .buttonStyle(.plain)
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                    .listRowSeparator(.hidden)
                }
                .onDelete(perform: delete)
            }
            .listStyle(.plain)
            .navigationTitle("Fine Schedule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showingNewEntry = true } label: { Image(systemName: "plus") }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .sheet(isPresented: $showingNewEntry) {
            FineScheduleEntrySheet(entry: nil) { offense, amountCents, description in
                guard let userId = appState.currentUserId else { return }
                Task { await viewModel.create(offense: offense, amountCents: amountCents, description: description, userId: userId) }
            }
        }
        .sheet(item: $editingEntry) { entry in
            FineScheduleEntrySheet(entry: entry) { offense, amountCents, description in
                guard let userId = appState.currentUserId else { return }
                Task { await viewModel.update(id: entry.id, offense: offense, amountCents: amountCents, description: description, userId: userId) }
            }
        }
    }

    private func delete(at offsets: IndexSet) {
        guard let userId = appState.currentUserId else { return }
        for index in offsets {
            let entry = viewModel.entries[index]
            Task { await viewModel.delete(id: entry.id, userId: userId) }
        }
    }
}
