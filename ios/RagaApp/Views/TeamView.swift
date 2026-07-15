import SwiftUI

/// Role-filtered menu of destinations, extending the app's existing
/// hand-rolled tab nav rather than introducing a new paradigm. Each row is
/// gated by `appState.capabilities` (server-resolved, never a client-side
/// guess) — rows for a subsystem the current role can't access simply don't
/// render, rather than showing a locked placeholder.
///
/// This is the one tab with its own NavigationStack; the other three stay
/// flat. New subsystem rows (Fines, Quotas, Props & Costumes, Comp
/// Applications, Competition Dashboard, Team Roster, Role Management) are
/// added here as each subsystem lands — see the plan's Milestone 2 join
/// points.
struct TeamView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        NavigationStack {
            List {
                Section("Operations") {
                    NavigationLink {
                        AttendanceEventPickerView()
                    } label: {
                        MenuRow(icon: "checklist", title: "Attendance", subtitle: "Check in team members at events")
                    }

                    if appState.capabilities?.practicePlanner.canAccess == true {
                        NavigationLink {
                            PracticePlannerView()
                        } label: {
                            MenuRow(icon: "calendar.badge.clock", title: "Practice Planner", subtitle: "Agenda + timeline for practices")
                        }
                    }
                }

                Section("Finance") {
                    NavigationLink {
                        FinesView()
                    } label: {
                        MenuRow(
                            icon: "dollarsign.circle",
                            title: "Fines",
                            subtitle: appState.capabilities?.fines.canManageAny == true ? "Send + manage fines" : "Your fines"
                        )
                    }

                    NavigationLink {
                        QuotasView()
                    } label: {
                        MenuRow(
                            icon: "chart.bar.fill",
                            title: "Quotas",
                            subtitle: appState.capabilities?.quotas.canManageAny == true ? "Manage member quotas" : "Your quota"
                        )
                    }
                }

                Section("Production") {
                    if appState.capabilities?.propsCostumes.mode != "NONE" {
                        NavigationLink {
                            PropsCostumesView()
                        } label: {
                            MenuRow(icon: "tshirt.fill", title: "Props & Costumes", subtitle: "Tasks, sizing, rentals, status")
                        }
                    }

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

                Section("Team") {
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
            .navigationTitle("Team")
        }
    }
}

private struct AttendanceEventPickerView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        List(appState.calendarEvents) { event in
            NavigationLink {
                AttendanceView(event: event)
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(event.label).font(.subheadline.bold())
                    Text(event.date, format: .dateTime.month(.abbreviated).day().year())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Attendance")
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if appState.calendarEvents.isEmpty {
                EmptyStateView(icon: "calendar", title: "No events yet", message: "Calendar events will show up here once scheduled.")
                    .padding(16)
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
