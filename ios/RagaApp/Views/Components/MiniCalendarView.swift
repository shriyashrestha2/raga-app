import SwiftUI

enum CalendarViewMode: String, CaseIterable, Identifiable {
    case week, month
    var id: String { rawValue }

    var label: String {
        switch self {
        case .week: return "Week"
        case .month: return "Month"
        }
    }
}

struct MiniCalendarView: View {
    @EnvironmentObject private var appState: AppState
    let events: [CalendarEventItem]
    let practices: [PracticeItem]
    /// Shared with NotificationsSectionView (owned by RoundupView) — tapping
    /// a day sets this and filters the feed below to that day; tapping the
    /// same day again clears it back to nil.
    @Binding var selectedDate: Date?
    /// Opens the same Add Notification flow the old standalone button used
    /// to trigger — the "+" here is now the single entry point for creating
    /// a notification (Calendar Events were retired).
    let onAddNotification: () -> Void

    @State private var viewMode: CalendarViewMode = .month
    @State private var currentDate: Date = {
        var components = DateComponents()
        components.year = 2026
        components.month = 10
        components.day = 1
        return Calendar.current.date(from: components) ?? Date()
    }()

    private let calendar = Calendar.current
    private let weekdaySymbols = ["S", "M", "T", "W", "T", "F", "S"]

    /// Only Captains and board positions can post — mirrors canCreateReminder
    /// in backend/src/permissions.ts, same gate the old Add Notification
    /// button used.
    private var canCreateReminder: Bool { appState.capabilities?.reminders.canCreate == true }

    /// Tapping a day highlights it (solid accent circle, matching the Figma
    /// prototype) and filters the feed below to that day; tapping the same
    /// day again clears the selection.
    private func toggleSelection(_ date: Date) {
        if let selectedDate, calendar.isDate(selectedDate, inSameDayAs: date) {
            self.selectedDate = nil
        } else {
            self.selectedDate = date
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            Picker("View", selection: $viewMode) {
                ForEach(CalendarViewMode.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)

            header

            switch viewMode {
            case .week: weekView
            case .month: monthView
            }

            Divider()
            legend
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(Color(.separator), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.06), radius: 12, y: 4)
    }

    // MARK: - Header

    private var headerTitle: String {
        switch viewMode {
        case .week:
            let days = weekDays(containing: currentDate)
            guard let first = days.first, let last = days.last else { return "" }
            let firstStr = first.formatted(.dateTime.month(.abbreviated).day())
            let lastStr = last.formatted(.dateTime.month(.abbreviated).day())
            return "\(firstStr) – \(lastStr), \(calendar.component(.year, from: last))"
        case .month:
            return currentDate.formatted(.dateTime.month(.wide).year())
        }
    }

    private var header: some View {
        HStack {
            Text(headerTitle)
                .font(.subheadline.bold())
            Spacer()
            HStack(spacing: 10) {
                Button("Today") { withAnimation { currentDate = Date() } }
                    .font(.caption2.bold())
                    .foregroundStyle(.primary)

                HStack(spacing: 4) {
                    Button { shift(-1) } label: {
                        Image(systemName: "chevron.left")
                    }
                    Button { shift(1) } label: {
                        Image(systemName: "chevron.right")
                    }
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.circle)
                .controlSize(.mini)

                if canCreateReminder {
                    Button(action: onAddNotification) {
                        Image(systemName: "plus")
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                            .frame(width: 26, height: 26)
                            .background(Color("AccentColor"), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .shadow(color: Color("AccentColor").opacity(0.35), radius: 4, y: 2)
                }
            }
        }
    }

    private func shift(_ delta: Int) {
        let component: Calendar.Component = viewMode == .week ? .weekOfYear : .month
        if let newDate = calendar.date(byAdding: component, value: delta, to: currentDate) {
            currentDate = newDate
        }
    }

    // MARK: - Day summary (events + practice merged, for dots and lists)

    private struct DaySummaryEntry: Identifiable {
        let id: String
        let category: CalendarCategory
        let label: String
    }

    private func summaryEntries(on date: Date) -> [DaySummaryEntry] {
        var entries = events(on: date).map { DaySummaryEntry(id: $0.id, category: $0.category, label: $0.label) }
        if let practice = practices.first(where: { calendar.isDate($0.date, inSameDayAs: date) }) {
            entries.append(DaySummaryEntry(id: "practice-\(practice.id)", category: .practice, label: practice.focus))
        }
        return entries
    }

    // MARK: - Month view

    private var monthDays: [Date?] {
        guard let range = calendar.range(of: .day, in: .month, for: currentDate),
              let firstOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: currentDate))
        else { return [] }

        let firstWeekday = calendar.component(.weekday, from: firstOfMonth) - 1 // 0 = Sunday
        var cells: [Date?] = Array(repeating: nil, count: firstWeekday)
        cells += range.compactMap { day in
            calendar.date(byAdding: .day, value: day - 1, to: firstOfMonth)
        }
        while cells.count % 7 != 0 { cells.append(nil) }
        return cells
    }

    private var monthView: some View {
        VStack(spacing: 8) {
            HStack {
                ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .font(.caption2.bold())
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                ForEach(Array(monthDays.enumerated()), id: \.offset) { _, date in
                    if let date {
                        let isToday = calendar.isDateInToday(date)
                        let isSelected = selectedDate.map { calendar.isDate($0, inSameDayAs: date) } ?? false
                        VStack(spacing: 3) {
                            Text("\(calendar.component(.day, from: date))")
                                .font(.caption.weight(isToday || isSelected ? .bold : .medium))
                                .foregroundStyle(isSelected ? .white : (isToday ? Color("AccentColor") : .primary))
                                .frame(width: 26, height: 26)
                                .background(
                                    Circle().fill(isSelected ? Color("AccentColor") : (isToday ? Color("AccentColor").opacity(0.14) : Color.clear))
                                )

                            HStack(spacing: 2) {
                                ForEach(summaryEntries(on: date).prefix(3)) { entry in
                                    Circle()
                                        .fill(entry.category.color)
                                        .frame(width: 5, height: 5)
                                }
                            }
                            .frame(height: 6)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { toggleSelection(date) }
                    } else {
                        Color.clear.frame(height: 32)
                    }
                }
            }
        }
    }

    // MARK: - Week view

    private func weekDays(containing date: Date) -> [Date] {
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: date) else { return [] }
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: weekInterval.start) }
    }

    /// A wide horizontal day strip — weekday letter, day-number circle, small
    /// dot row below — matching the Figma prototype's week view exactly,
    /// rather than a vertical stacked list. Tapping a day selects it, same as
    /// monthView; the day's items show in the feed below, not inline here.
    private var weekView: some View {
        HStack(spacing: 0) {
            ForEach(weekDays(containing: currentDate), id: \.self) { date in
                weekDayColumn(date)
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                    .onTapGesture { toggleSelection(date) }
            }
        }
    }

    private func weekDayColumn(_ date: Date) -> some View {
        let isToday = calendar.isDateInToday(date)
        let isSelected = selectedDate.map { calendar.isDate($0, inSameDayAs: date) } ?? false
        return VStack(spacing: 8) {
            Text(date.formatted(.dateTime.weekday(.abbreviated)))
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)

            Text("\(calendar.component(.day, from: date))")
                .font(.subheadline.weight(isToday || isSelected ? .bold : .medium))
                .foregroundStyle(isSelected ? .white : (isToday ? Color("AccentColor") : .primary))
                .frame(width: 38, height: 38)
                .background(
                    Circle().fill(isSelected ? Color("AccentColor") : (isToday ? Color("AccentColor").opacity(0.14) : Color.clear))
                )

            HStack(spacing: 2) {
                ForEach(summaryEntries(on: date).prefix(3)) { entry in
                    Circle().fill(entry.category.color).frame(width: 5, height: 5)
                }
            }
            .frame(height: 6)
        }
        .padding(.vertical, 6)
    }

    // MARK: - Shared

    private let legendOrder: [CalendarCategory] = [.captains, .production, .finance, .logistics, .social, .practice]

    private var legend: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 6) {
            ForEach(legendOrder, id: \.self) { category in
                HStack(spacing: 6) {
                    Circle().fill(category.color).frame(width: 8, height: 8)
                    Text(category.label)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func events(on date: Date) -> [CalendarEventItem] {
        events.filter { calendar.isDate($0.date, inSameDayAs: date) }
            .sorted { $0.date < $1.date }
    }
}

extension CalendarCategory {
    var color: Color {
        switch self {
        case .finance: return .green
        case .practice: return .blue
        case .captains: return Color("AccentColor")
        case .production: return .purple
        case .social: return .yellow
        case .logistics: return .orange
        }
    }
}
