import SwiftUI

/// Shared empty/restricted-access state, matching the app's existing card
/// language (secondarySystemGroupedBackground, 24pt continuous corner
/// radius, hairline separator stroke). Used for genuine empty lists and for
/// "you don't have access to this" fallbacks — not for content that should
/// be entirely absent from a role's UI (e.g. choreo/formation reminders,
/// which simply never render for non-Captains rather than showing a locked
/// placeholder).
struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 32))
                .foregroundStyle(.secondary)
                .padding(.bottom, 4)
            Text(title)
                .font(.subheadline.bold())
                .multilineTextAlignment(.center)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.bordered)
                    .tint(Color("AccentColor"))
                    .controlSize(.small)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(Color(.separator), lineWidth: 0.5))
    }
}

extension EmptyStateView {
    static func restrictedAccess() -> EmptyStateView {
        EmptyStateView(
            icon: "lock.fill",
            title: "You don't have access to this",
            message: "This section isn't available for your current role."
        )
    }
}
