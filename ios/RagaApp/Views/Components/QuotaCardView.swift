import SwiftUI

/// Quota card shown both in a manager's roster view (Captain/Finance, one
/// per member) and a non-manager's own single-quota view. Progress is
/// itemized — each contribution names the event/source it came from — rather
/// than a single manually-adjusted number, so `currentValue` is always just
/// the sum of `quota.contributions` (server-derived, never set directly).
/// Logging a contribution, editing the target, and deleting are all
/// manager-only (per the permission matrix, everyone else can only view
/// their own quota) — those controls only render when `canManage` is true.
struct QuotaCardView: View {
    let quota: QuotaItem
    var canManage: Bool = false
    var unpaidFineCents: Int = 0
    var unpaidFineCount: Int = 0
    var onAddContribution: (String, Double) -> Void = { _, _ in }
    var onUpdateTarget: (Double) -> Void = { _ in }
    var onDelete: () -> Void = {}

    @State private var showDeleteConfirm = false
    @State private var showingAddContribution = false
    @State private var showingEditTarget = false
    @State private var isExpanded = false

    private var fraction: Double {
        guard quota.targetValue > 0 else { return 0 }
        return min(max(quota.currentValue / quota.targetValue, 0), 1)
    }

    private var isComplete: Bool {
        quota.targetValue > 0 && quota.currentValue >= quota.targetValue
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            VStack(alignment: .leading, spacing: 6) {
                ProgressView(value: fraction)
                    .tint(isComplete ? .green : Color("AccentColor"))

                HStack {
                    Text(progressText)
                        .font(.caption.bold())
                        .foregroundStyle(isComplete ? .green : .secondary)
                    Spacer()
                    if let dueDate = quota.dueDate {
                        Label(dueDate.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if unpaidFineCount > 0 {
                Label(
                    "\(unpaidFineCount) unpaid fine\(unpaidFineCount == 1 ? "" : "s") · \((Double(unpaidFineCents) / 100).formatted(.currency(code: "USD")))",
                    systemImage: "dollarsign.circle.fill"
                )
                .font(.caption.bold())
                .foregroundStyle(.orange)
            }

            contributionsDisclosure

            if canManage {
                Button {
                    showingAddContribution = true
                } label: {
                    Label("Add Contribution", systemImage: "plus.circle.fill")
                        .font(.caption.bold())
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(Color("AccentColor"))
                .controlSize(.small)
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(Color(.separator), lineWidth: 0.5))
        .confirmationDialog("Delete this quota?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive, action: onDelete)
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showingAddContribution) {
            NewContributionSheet(unit: quota.unit) { event, amount in
                onAddContribution(event, amount)
            }
        }
        .sheet(isPresented: $showingEditTarget) {
            EditQuotaTargetSheet(label: quota.label, unit: quota.unit, currentTarget: quota.targetValue) { newTarget in
                onUpdateTarget(newTarget)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color("AccentColor").opacity(0.15))
                .frame(width: 40, height: 40)
                .overlay(
                    Text(quota.user.initials)
                        .font(.caption.bold())
                        .foregroundStyle(Color("AccentColor"))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(quota.label)
                    .font(.subheadline.bold())
                Text(quota.user.name)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            if canManage {
                Menu {
                    Button {
                        showingEditTarget = true
                    } label: {
                        Label("Edit Target", systemImage: "pencil")
                    }
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Label("Delete Quota", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var contributionsDisclosure: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(spacing: 6) {
                if quota.contributions.isEmpty {
                    Text("No contributions logged yet.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 4)
                } else {
                    ForEach(quota.contributions) { contribution in
                        ContributionRow(contribution: contribution, unit: quota.unit)
                    }
                }
            }
            .padding(.top, 6)
        } label: {
            Text("How this was raised (\(quota.contributions.count))")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
        }
    }

    private var progressText: String {
        "\(formatted(quota.currentValue)) / \(formatted(quota.targetValue)) \(quota.unit)"
    }

    private func formatted(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", value)
            : String(format: "%.1f", value)
    }
}

private struct ContributionRow: View {
    let contribution: QuotaContribution
    let unit: String

    private var amountText: String {
        unit == "USD"
            ? contribution.amount.formatted(.currency(code: "USD"))
            : "\(formattedAmount) \(unit)"
    }

    private var formattedAmount: String {
        contribution.amount.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", contribution.amount)
            : String(format: "%.1f", contribution.amount)
    }

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 1) {
                Text(contribution.event)
                    .font(.caption.bold())
                Text(contribution.createdAt, style: .date)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Text(amountText)
                .font(.caption.bold())
                .foregroundStyle(Color("AccentColor"))
        }
        .padding(10)
        .background(Color(.tertiarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct NewContributionSheet: View {
    @Environment(\.dismiss) private var dismiss
    let unit: String
    let onCreate: (String, Double) -> Void

    @State private var event: String = ""
    @State private var amountText: String = ""

    private var amount: Double? {
        guard let value = Double(amountText), value > 0 else { return nil }
        return value
    }

    private var isValid: Bool {
        !event.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && amount != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Event or Source") {
                    TextField("e.g. Bake Sale, Dues installment", text: $event)
                }
                Section("Amount (\(unit))") {
                    TextField("0", text: $amountText)
                        .keyboardType(.decimalPad)
                }
            }
            .navigationTitle("Add Contribution")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        guard let amount else { return }
                        onCreate(event.trimmingCharacters(in: .whitespacesAndNewlines), amount)
                        dismiss()
                    }
                    .disabled(!isValid)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

private struct EditQuotaTargetSheet: View {
    @Environment(\.dismiss) private var dismiss
    let label: String
    let unit: String
    let currentTarget: Double
    let onSave: (Double) -> Void

    @State private var targetText: String

    init(label: String, unit: String, currentTarget: Double, onSave: @escaping (Double) -> Void) {
        self.label = label
        self.unit = unit
        self.currentTarget = currentTarget
        self.onSave = onSave
        _targetText = State(initialValue: currentTarget.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", currentTarget)
            : String(currentTarget))
    }

    private var newTarget: Double? {
        guard let value = Double(targetText), value > 0 else { return nil }
        return value
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("\(label) Target (\(unit))") {
                    TextField("0", text: $targetText)
                        .keyboardType(.decimalPad)
                }
            }
            .navigationTitle("Edit Target")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard let newTarget else { return }
                        onSave(newTarget)
                        dismiss()
                    }
                    .disabled(newTarget == nil)
                }
            }
        }
        .presentationDetents([.medium])
    }
}
