import SwiftUI

/// Add/edit form for a single fine-schedule offense. Exactly one of a fixed
/// dollar amount or a plain-text variable-rule description is provided,
/// mirroring the server's mutual-exclusivity validation.
struct FineScheduleEntrySheet: View {
    @Environment(\.dismiss) private var dismiss
    let entry: FineScheduleEntry?
    let onSave: (String, Int?, String?) -> Void

    @State private var offense: String
    @State private var isVariable: Bool
    @State private var amountText: String
    @State private var description: String

    init(entry: FineScheduleEntry?, onSave: @escaping (String, Int?, String?) -> Void) {
        self.entry = entry
        self.onSave = onSave
        _offense = State(initialValue: entry?.offense ?? "")
        _isVariable = State(initialValue: entry?.isVariable ?? false)
        _amountText = State(initialValue: entry?.amountCents.map { String(format: "%.2f", Double($0) / 100.0) } ?? "")
        _description = State(initialValue: entry?.description ?? "")
    }

    private var amountCents: Int? {
        guard let dollars = Double(amountText), dollars > 0 else { return nil }
        return Int((dollars * 100).rounded())
    }

    private var isValid: Bool {
        guard !offense.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        if isVariable {
            return !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return amountCents != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Offense") {
                    TextField("e.g. Late to Practice", text: $offense)
                }
                Section("Amount") {
                    Toggle("Variable amount", isOn: $isVariable)
                    if isVariable {
                        TextField("Describe the rule", text: $description, axis: .vertical)
                            .lineLimit(2...4)
                    } else {
                        HStack {
                            Text("$").foregroundStyle(.secondary)
                            TextField("0.00", text: $amountText)
                                .keyboardType(.decimalPad)
                        }
                    }
                }
            }
            .navigationTitle(entry == nil ? "New Offense" : "Edit Offense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let trimmedOffense = offense.trimmingCharacters(in: .whitespacesAndNewlines)
                        if isVariable {
                            onSave(trimmedOffense, nil, description.trimmingCharacters(in: .whitespacesAndNewlines))
                        } else {
                            onSave(trimmedOffense, amountCents, nil)
                        }
                        dismiss()
                    }
                    .disabled(!isValid)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
