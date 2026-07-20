import SwiftUI

/// Finance tab content (Team page → Finance): Fundraising + Fines Tracker,
/// laid out as a single scroll like RoundupView's per-tab content. A Quotas
/// link is kept at the top so that existing functionality (previously a
/// "Finance" list section on the old Team page) doesn't lose a navigable
/// entry point now that Fines/Fundraising live inline here instead.
struct FinanceTabView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                quotasLink
                FundraisingSectionView()
                Divider()
                FinesTrackerSectionView()
            }
            .padding(16)
        }
    }

    private var quotasLink: some View {
        NavigationLink {
            QuotasView()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "chart.bar.fill")
                    .foregroundStyle(Color("AccentColor"))
                    .frame(width: 28, height: 28)
                    .background(Color("AccentColor").opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                VStack(alignment: .leading, spacing: 1) {
                    Text("Quotas").font(.subheadline.bold())
                    Text(appState.capabilities?.quotas.canManageAny == true ? "Manage member quotas" : "Your quota")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(Color(.separator), lineWidth: 0.5))
        }
        .buttonStyle(.plain)
    }
}
