import SwiftUI

enum TeamTab: String, CaseIterable, Identifiable {
    case operations, finance, production, logistics, team
    var id: String { rawValue }

    var title: String {
        switch self {
        case .operations: return "Operations"
        case .finance: return "Finance"
        case .production: return "Production"
        case .logistics: return "Logistics"
        case .team: return "Team"
        }
    }
}

/// Role-filtered menu of destinations, extending the app's existing
/// hand-rolled tab nav rather than introducing a new paradigm. Each row is
/// gated by `appState.capabilities` (server-resolved, never a client-side
/// guess) — rows for a subsystem the current role can't access simply don't
/// render, rather than showing a locked placeholder.
///
/// This is the one tab with its own NavigationStack; the other three stay
/// flat. Sub-tabs (Operations/Finance/Production/Logistics/Team) mirror
/// RoundupView's segmented-picker pattern — the old single List with 4
/// Sections is now 5 per-tab Lists (Finance instead renders a second, nested
/// segmented picker of its own — Fundraising/Quotas/Fines — see FinanceTabView).
struct TeamView: View {
    @EnvironmentObject private var appState: AppState
    @State private var tab: TeamTab = .operations

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("", selection: $tab) {
                    ForEach(TeamTab.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.top, 12)

                Group {
                    switch tab {
                    case .operations: operationsList
                    case .finance: FinanceTabView()
                    case .production: productionList
                    case .logistics: logisticsList
                    case .team: teamList
                    }
                }
            }
        }
    }

    private var operationsList: some View {
        List {
            NavigationLink {
                PracticeAttendanceView()
            } label: {
                MenuRow(icon: "checklist", title: "Attendance", subtitle: "Practice attendance, present/late/absent")
            }

            if appState.capabilities?.practicePlanner.canAccess == true {
                NavigationLink {
                    PracticePlannerView()
                } label: {
                    MenuRow(icon: "calendar.badge.clock", title: "Practice Planner", subtitle: "Agenda + timeline for practices")
                }
            }
        }
    }

    private var productionList: some View {
        List {
            if appState.capabilities?.propsCostumes.mode != "NONE" {
                NavigationLink {
                    PropsCostumesView()
                } label: {
                    MenuRow(icon: "tshirt.fill", title: "Props & Costumes", subtitle: "Tasks, sizing, rentals, status")
                }
            }
        }
    }

    private var logisticsList: some View {
        List {
            if appState.capabilities?.compApplications.canAccess == true {
                NavigationLink {
                    CompApplicationsView()
                } label: {
                    MenuRow(icon: "doc.text.magnifyingglass", title: "Comp Applications", subtitle: "Packet submissions + deadlines")
                }
            }

            NavigationLink {
                CompetitionDashboardView()
            } label: {
                MenuRow(icon: "trophy.fill", title: "Competition Dashboard", subtitle: "Schedule + role sections")
            }
        }
    }

    private var teamList: some View {
        List {
            NavigationLink {
                TeamRosterView()
            } label: {
                MenuRow(icon: "person.3.fill", title: "Team Roster", subtitle: "Team info + member contacts")
            }

            if appState.capabilities?.roleManagement.canAccess == true {
                NavigationLink {
                    RoleManagementView()
                } label: {
                    MenuRow(icon: "person.badge.key.fill", title: "Role Management", subtitle: "Assign member roles")
                }
            }
        }
    }
}

private struct MenuRow: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(Color("AccentColor"))
                .frame(width: 28, height: 28)
                .background(Color("AccentColor").opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.subheadline.bold())
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}
