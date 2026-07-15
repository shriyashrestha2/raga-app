import SwiftUI

enum AppTab: String, CaseIterable, Identifiable {
    case roundup, practice, videos, team
    var id: String { rawValue }

    var title: String {
        switch self {
        case .roundup: return "Roundup"
        case .practice: return "Practice"
        case .videos: return "Videos"
        case .team: return "Team"
        }
    }

    var symbol: String {
        switch self {
        case .roundup: return "megaphone.fill"
        case .practice: return "calendar"
        case .videos: return "play.fill"
        case .team: return "person.3.fill"
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var appState: AppState
    @State private var tab: AppTab = .roundup

    var body: some View {
        VStack(spacing: 0) {
            TopHeaderView(title: tab.title)

            Group {
                switch tab {
                case .roundup: RoundupView()
                case .practice: PracticeView()
                case .videos: VideosView()
                case .team: TeamView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemGroupedBackground))

            BottomNavView(tab: $tab)
        }
        .alert("Something went wrong", isPresented: Binding(
            get: { appState.errorMessage != nil },
            set: { if !$0 { appState.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { appState.errorMessage = nil }
        } message: {
            Text(appState.errorMessage ?? "")
        }
    }
}

private struct TopHeaderView: View {
    @EnvironmentObject private var appState: AppState
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .lastTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("RU RAGA · Fall 2026")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white.opacity(0.7))
                        .textCase(.uppercase)
                    Text(title)
                        .font(.title.bold())
                        .foregroundStyle(.white)
                }
                Spacer()
                Menu {
                    ForEach(appState.users) { user in
                        Button {
                            Task { await appState.switchUser(to: user.id) }
                        } label: {
                            Label("\(user.name) · \(user.role.label)", systemImage: user.role.symbol)
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: appState.role.symbol)
                        Text(appState.role.label)
                            .fontWeight(.bold)
                    }
                    .font(.caption)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.white.opacity(0.15), in: Capsule())
                    .overlay(Capsule().stroke(.white.opacity(0.2)))
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color("AccentColor").ignoresSafeArea(edges: .top))
    }
}

private struct BottomNavView: View {
    @Binding var tab: AppTab

    var body: some View {
        HStack {
            ForEach(AppTab.allCases) { item in
                Button {
                    tab = item
                } label: {
                    VStack(spacing: 4) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(tab == item ? Color("AccentColor") : Color.clear)
                                .frame(width: 40, height: 40)
                            Image(systemName: item.symbol)
                                .foregroundStyle(tab == item ? .white : .secondary)
                        }
                        Text(item.title)
                            .font(.caption2.bold())
                            .foregroundStyle(tab == item ? Color("AccentColor") : .secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 8)
        .padding(.horizontal, 12)
        .background(
            Color(.secondarySystemGroupedBackground)
                .overlay(alignment: .top) {
                    Rectangle().fill(Color(.separator)).frame(height: 0.5)
                }
        )
    }
}
