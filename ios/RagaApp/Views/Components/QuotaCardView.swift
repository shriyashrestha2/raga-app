import SwiftUI

/// Quota card shown both in a manager's roster view (Captain/Finance, one
/// per member) and a non-manager's own single-quota view. Progress edits
/// are manager-only (per the permission matrix, everyone else can only
/// view their own quota) — the stepper/delete controls only render when
/// `canManage` is true.
struct QuotaCardView: View {
    let quota: QuotaItem
    var canManage: Bool = false
    var onUpdateProgress: (Double) -> Void = { _ in }
    var onDelete: () -> Void = {}

    @State private var showDeleteConfirm = false

    private var fraction: Double {
        guard quota.targetValue > 0 else { return 0 }
        return min(max(quota.currentValue / quota.targetValue, 0), 1)
    }

    private var isComplete: Bool {
        quota.targetValue > 0 && quota.currentValue >= quota.targetValue
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
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

            if canManage {
                HStack(spacing: 8) {
                    Button {
                        onUpdateProgress(max(0, quota.currentValue - 1))
                    } label: {
                        Image(systemName: "minus")
                    }
                    .buttonStyle(.bordered)
                    .disabled(quota.currentValue <= 0)

                    Button {
                        onUpdateProgress(quota.currentValue + 1)
                    } label: {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(.bordered)

                    Text("Adjust progress")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
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
