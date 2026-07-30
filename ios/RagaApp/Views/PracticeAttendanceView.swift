import SwiftUI

/// Team → Attendance. Captains get the full mark/track dashboard
/// (`PracticeAttendanceDashboardView`); everyone else gets a read-only
/// history of their own present/late/absent status per practice
/// (`PracticeAttendanceListView`).
struct PracticeAttendanceView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        if appState.capabilities?.practiceAttendance.canManageAny == true {
            PracticeAttendanceDashboardView()
        } else {
            PracticeAttendanceListView()
        }
    }
}

// MARK: - Captain dashboard

private enum StatusFilter: Hashable {
    case all
    case status(AttendanceStatus)
    case unmarked

    var label: String {
        switch self {
        case .all: return "All"
        case .unmarked: return "Unmarked"
        case .status(let s): return s.label
        }
    }
}

struct PracticeAttendanceDashboardView: View {
    @EnvironmentObject private var appState: AppState

    @State private var selectedPracticeId: String?
    @State private var records: [PracticeAttendanceRecord] = []
    @State private var isLoading = false
    @State private var search = ""
    @State private var filter: StatusFilter = .all

    private var sortedPractices: [PracticeItem] {
        appState.practices.sorted { $0.date < $1.date }
    }

    private var selectedPractice: PracticeItem? {
        sortedPractices.first { $0.id == selectedPracticeId }
    }

    private var present: Int { records.filter { $0.status == .present }.count }
    private var absent: Int { records.filter { $0.status == .absent }.count }
    private var late: Int { records.filter { $0.status == .late }.count }
    private var marked: Int { records.filter { $0.status != nil }.count }
    private var unmarked: Int { records.count - marked }
    private var presentRate: Double {
        marked == 0 ? 0 : Double(present) / Double(marked) * 100
    }

    private var visibleRecords: [PracticeAttendanceRecord] {
        records.filter { record in
            let matchesFilter: Bool
            switch filter {
            case .all: matchesFilter = true
            case .unmarked: matchesFilter = record.status == nil
            case .status(let s): matchesFilter = record.status == s
            }
            guard matchesFilter else { return false }
            guard !search.trimmingCharacters(in: .whitespaces).isEmpty else { return true }
            return record.name.localizedCaseInsensitiveContains(search)
                || record.role.label.localizedCaseInsensitiveContains(search)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 16)
                .padding(.top, 8)

            if sortedPractices.isEmpty {
                Spacer()
                EmptyStateView(icon: "checklist", title: "No practices yet", message: "Attendance shows up here once practices are scheduled.")
                    .padding(16)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        if visibleRecords.isEmpty {
                            Text("No people match this filter.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.top, 32)
                        } else {
                            ForEach(visibleRecords) { record in
                                PracticeAttendanceRowView(record: record) {
                                    Task { await cycleStatus(record) }
                                }
                            }
                        }
                    }
                    .padding(16)
                }
            }
        }
        .navigationTitle("Attendance")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if selectedPracticeId == nil { selectedPracticeId = defaultPracticeId }
            await loadRecords()
        }
        .onChange(of: selectedPracticeId) { _, _ in
            Task { await loadRecords() }
        }
        .refreshable { await loadRecords() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Practice Sessions")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(sortedPractices) { practice in
                                SessionTabView(
                                    label: sessionLabel(for: practice.date),
                                    isSelected: practice.id == selectedPracticeId
                                ) {
                                    selectedPracticeId = practice.id
                                }
                            }
                        }
                    }
                }
                Spacer(minLength: 8)
                Button {
                    Task { await markAll(.present) }
                } label: {
                    Text("Mark All")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color("AccentColor"), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .disabled(selectedPracticeId == nil)
            }

            statsCard

            searchField

            filterPills
        }
    }

    private var statsCard: some View {
        HStack(spacing: 16) {
            CircleProgressView(pct: presentRate)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                statTile(label: "Present", value: present, color: .green)
                statTile(label: "Absent", value: absent, color: Color("AccentColor"))
                statTile(label: "Late", value: late, color: .orange)
                statTile(label: "Unmarked", value: unmarked, color: .secondary)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Color(.separator), lineWidth: 0.5))
    }

    private func statTile(label: String, value: Int, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("\(value)").font(.headline.bold()).foregroundStyle(color)
            Text(label).font(.caption2).foregroundStyle(color.opacity(0.8))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("Search people...", text: $search)
        }
        .font(.subheadline)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color(.separator), lineWidth: 0.5))
    }

    private var filterPills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                filterPill(.all, count: records.count)
                filterPill(.status(.present), count: present)
                filterPill(.status(.absent), count: absent)
                filterPill(.status(.late), count: late)
                filterPill(.unmarked, count: unmarked)
            }
        }
    }

    private func filterPill(_ f: StatusFilter, count: Int) -> some View {
        let isActive = filter == f
        let color: Color = {
            switch f {
            case .all: return .primary
            case .unmarked: return .secondary
            case .status(.present): return .green
            case .status(.absent): return Color("AccentColor")
            case .status(.late): return .orange
            case .status(.excused): return .blue
            }
        }()
        return Button {
            filter = f
        } label: {
            Text("\(f.label) (\(count))")
                .font(.caption.bold())
                .foregroundStyle(isActive ? .white : color)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isActive ? color : Color.clear, in: Capsule())
                .overlay(Capsule().strokeBorder(isActive ? Color.clear : Color(.separator), lineWidth: 1))
        }
    }

    private var defaultPracticeId: String? {
        let now = Date()
        if let closestPast = sortedPractices.last(where: { $0.date <= now }) {
            return closestPast.id
        }
        return sortedPractices.first?.id
    }

    private func sessionLabel(for date: Date) -> String {
        if Calendar.current.isDateInToday(date) { return "Today" }
        if Calendar.current.isDateInYesterday(date) { return "Yesterday" }
        return date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
    }

    private func loadRecords() async {
        guard let practiceId = selectedPracticeId, let userId = appState.currentUserId else { return }
        isLoading = true
        defer { isLoading = false }
        if let result = try? await APIClient.shared.fetchPracticeAttendance(practiceId: practiceId, userId: userId) {
            records = result.records
        }
    }

    private func cycleStatus(_ record: PracticeAttendanceRecord) async {
        guard let practiceId = selectedPracticeId, let userId = appState.currentUserId else { return }
        let order: [AttendanceStatus?] = [nil, .present, .absent, .late]
        let currentIndex = order.firstIndex(of: record.status) ?? 0
        let next = order[(currentIndex + 1) % order.count]

        guard let next else {
            await loadRecords()
            return
        }
        try? await APIClient.shared.markPracticeAttendance(practiceId: practiceId, targetUserId: record.userId, status: next, userId: userId)
        await loadRecords()
    }

    private func markAll(_ status: AttendanceStatus) async {
        guard let practiceId = selectedPracticeId, let userId = appState.currentUserId else { return }
        try? await APIClient.shared.markAllPracticeAttendance(practiceId: practiceId, status: status, userId: userId)
        await loadRecords()
    }
}

private struct SessionTabView: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.caption.bold())
                .foregroundStyle(isSelected ? .white : .secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.black : Color(.tertiarySystemFill), in: Capsule())
        }
    }
}

private struct CircleProgressView: View {
    let pct: Double

    var body: some View {
        ZStack {
            Circle().stroke(Color(.tertiarySystemFill), lineWidth: 7)
            Circle()
                .trim(from: 0, to: min(max(pct / 100, 0), 1))
                .stroke(Color("AccentColor"), style: StrokeStyle(lineWidth: 7, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text("\(Int(pct.rounded()))%").font(.subheadline.bold())
                Text("rate").font(.caption2).foregroundStyle(.secondary)
            }
        }
        .frame(width: 72, height: 72)
    }
}

private struct PracticeAttendanceRowView: View {
    let record: PracticeAttendanceRecord
    let onTap: () -> Void

    private var statusColor: Color {
        switch record.status {
        case .present: return .green
        case .late: return .orange
        case .excused: return .blue
        case .absent: return Color("AccentColor")
        case nil: return .secondary
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Text(record.initials)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
                .frame(width: 40, height: 40)
                .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(record.name).font(.subheadline.bold())
                Text(record.role.label).font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()

            Button(action: onTap) {
                Text(record.status?.label ?? "Mark")
                    .font(.caption2.bold())
                    .foregroundStyle(record.status == nil ? Color.secondary : Color.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(record.status == nil ? Color(.tertiarySystemFill) : statusColor, in: Capsule())
            }
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Color(.separator), lineWidth: 0.5))
    }
}

// MARK: - Non-captain: read-only list of practices with own status

struct PracticeAttendanceListView: View {
    @EnvironmentObject private var appState: AppState

    private var sortedPractices: [PracticeItem] {
        appState.practices.sorted { $0.date > $1.date }
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                if sortedPractices.isEmpty {
                    EmptyStateView(icon: "checklist", title: "No practices yet", message: "Your attendance will show up here once practices are scheduled.")
                        .padding(.top, 40)
                } else {
                    ForEach(sortedPractices) { practice in
                        PracticeAttendanceHistoryRow(practice: practice)
                    }
                }
            }
            .padding(16)
        }
        .navigationTitle("Attendance")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await appState.loadPractices() }
    }
}

private struct PracticeAttendanceHistoryRow: View {
    let practice: PracticeItem

    private var statusColor: Color {
        switch practice.myAttendance {
        case .present: return .green
        case .late: return .orange
        case .excused: return .blue
        case .absent: return Color("AccentColor")
        case nil: return .secondary
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 2) {
                Text(practice.date, format: .dateTime.day())
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                Text(practice.date, format: .dateTime.weekday(.abbreviated))
                    .font(.caption2.bold())
                    .foregroundStyle(.white.opacity(0.75))
            }
            .frame(width: 56)
            .frame(maxHeight: .infinity)
            .background(Color("AccentColor"))

            VStack(alignment: .leading, spacing: 3) {
                Text(practice.focus).font(.subheadline.bold())
                Label(practice.location, systemImage: "mappin.and.ellipse")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            Spacer(minLength: 8)

            Text(practice.myAttendance?.label ?? "Not marked")
                .font(.caption2.bold())
                .foregroundStyle(practice.myAttendance == nil ? Color.secondary : Color.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(practice.myAttendance == nil ? Color(.tertiarySystemFill) : statusColor, in: Capsule())
                .padding(.trailing, 12)
        }
        .frame(minHeight: 64)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Color(.separator), lineWidth: 0.5))
    }
}
