import SwiftUI

enum FinanceSubTab: String, CaseIterable, Identifiable {
    case fundraising, quotas, fines
    var id: String { rawValue }

    var title: String {
        switch self {
        case .fundraising: return "Fundraising"
        case .quotas: return "Quotas"
        case .fines: return "Fines"
        }
    }
}

/// Finance tab content (Team page → Finance): a second, nested segmented
/// picker — same mechanism TeamView uses one level up — choosing between
/// Fundraising, Quotas, and Fines.
///
/// Fundraising has no "own record" for a non-board member to fall back to
/// (it's team totals only), so it's the one sub-tab actually removed from
/// this picker for non-board roles — see `visibleSubTabs`. Quotas/Fines stay
/// visible for everyone: the server already scopes their content to "your
/// own" for non-board viewers (see backend/src/routes/quotas.ts, fines.ts),
/// so no client-side hiding is needed there — only the always-visible
/// "Finance" tab one level up in TeamView guarantees they can still reach
/// their own quota/fines.
struct FinanceTabView: View {
    @EnvironmentObject private var appState: AppState
    @State private var subTab: FinanceSubTab = .fundraising

    private var visibleSubTabs: [FinanceSubTab] {
        FinanceSubTab.allCases.filter { candidate in
            switch candidate {
            case .fundraising: return appState.capabilities?.fundraising.canViewAny == true
            default: return true
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $subTab) {
                ForEach(visibleSubTabs) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.top, 12)

            Group {
                switch subTab {
                case .fundraising: fundraisingContent
                case .quotas: QuotasView()
                case .fines: finesContent
                }
            }
        }
        .onChange(of: appState.capabilities?.fundraising.canViewAny) { _, canView in
            if subTab == .fundraising && canView != true { subTab = .quotas }
        }
    }

    private var fundraisingContent: some View {
        ScrollView {
            FundraisingSectionView()
                .padding(16)
        }
    }

    private var finesContent: some View {
        ScrollView {
            FinesTrackerSectionView()
                .padding(16)
        }
    }
}
