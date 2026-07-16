import SwiftUI

enum CalendarViewMode: String, CaseIterable, Identifiable {
    case day, week, month, year
    var id: String { rawValue }

    var label: String {
        switch self {
        case .day: return "Day"
        case .week: return "Week"
        case .month: return "Month"
        case .year: return "Year"
        }
    }
}

struct MiniCalendarView: View {
    @EnvironmentObject private var appState: AppState
    let events: [CalendarEventItem]

    @State private var viewMode: CalendarViewMode = .month
    @State private var currentDate: Date = {
        var components = DateComponents()
        components.year = 2026
        components.month = 10
        components.day = 1
        return Calendar.current.date(from: components) ?? Date()
    }()
    @State private var selectedDate: Date?
    @State private var newEventDate: Date?

    private let calendar = Calendar.current
    private let weekdaySymbols = ["S", "M", "T", "W", "T", "F", "S"]

    /// Mirrors the server's POST /calendar gate: Captains and the
    /// role-owned categories (Finance/Production/Logistics) can add events;
    /// everyone else uses the Reminders tab instead.
    private var canCreateEvent: Bool {
        appState.capabilities?.calendar.canEditAny == true || appState.capabilities?.calendar.editableCategory != nil
    }

    /// Tap opens the day's event breakdown; long-press starts adding a new
    /// event on that date. Plain `.onTapGesture` has no maximum duration, so
    /// it would also fire after a long press's release — composing the two
    /// gestures with `.exclusively(before:)` ensures only one wins per touch.
    private func dateGesture(for date: Date) -> some Gesture {
        LongPressGesture(minimumDuration: 0.4)
            .exclusively(before: TapGesture())
            .onEnded { result in
                switch result {
                case .first:
                    guard canCreateEvent else { return }
                    newEventDate = date
                case .second:
                    selectedDate = date
                }
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
            case .day: dayView
            case .week: weekView
            case .month: monthView
            case .year: yearView
            }

            Divider()
            legend
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(Color(.separator), lineWidth: 0.5))
        .sheet(isPresented: Binding(
            get: { selectedDate != nil },
            set: { if !$0 { selectedDate = nil } }
        )) {
            if let selectedDate {
                CalendarDayDetailSheet(date: selectedDate, events: events(on: selectedDate))
            }
        }
        .sheet(isPresented: Binding(
            get: { newEventDate != nil },
            set: { if !$0 { newEventDate = nil } }
        )) {
            if let newEventDate {
                NewCalendarEventSheet(initialDate: newEventDate, role: appState.role) { label, description, date, category, visibleToRoles in
                    Task {
                        await appState.createCalendarEvent(date: date, category: category, label: label, description: description, visibleToRoles: visibleToRoles)
                    }
                }
            }
        }
    }

    // MARK: - Header

    private var headerTitle: String {
        switch viewMode {
        case .day:
            return currentDate.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
        case .week:
            let days = weekDays(containing: currentDate)
            guard let first = days.first, let last = days.last else { return "" }
            let firstStr = first.formatted(.dateTime.month(.abbreviated).day())
            let lastStr = last.formatted(.dateTime.month(.abbreviated).day())
            return "\(firstStr) – \(lastStr), \(calendar.component(.year, from: last))"
        case .month:
            return currentDate.formatted(.dateTime.month(.wide).year())
        case .year:
            return currentDate.formatted(.dateTime.year())
        }
    }

    private var header: some View {
        HStack {
            Text(headerTitle)
                .font(.subheadline.bold())
            Spacer()
            HStack(spacing: 4) {
                Button("Today") { currentDate = Date() }
                    .font(.caption2.bold())
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
        }
    }

    private func shift(_ delta: Int) {
        let component: Calendar.Component
        switch viewMode {
        case .day: component = .day
        case .week: component = .weekOfYear
        case .month: component = .month
        case .year: component = .year
        }
        if let newDate = calendar.date(byAdding: component, value: delta, to: currentDate) {
            currentDate = newDate
        }
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
        VStack(spacing: 6) {
            HStack {
                ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .font(.caption2.bold())
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 6) {
                ForEach(Array(monthDays.enumerated()), id: \.offset) { _, date in
                    if let date {
                        VStack(spacing: 3) {
                            Text("\(calendar.component(.day, from: date))")
                                .font(.caption.weight(calendar.isDateInToday(date) ? .bold : .medium))
                                .foregroundStyle(calendar.isDateInToday(date) ? .white : .primary)
                                .frame(width: 24, height: 24)
                                .background(calendar.isDateInToday(date) ? Color("AccentColor") : Color.clear, in: Circle())

                            HStack(spacing: 2) {
                                ForEach(events(on: date).prefix(3)) { event in
                                    Circle()
                                        .fill(event.category.color)
                                        .frame(width: 5, height: 5)
                                }
                            }
                            .frame(height: 6)
                        }
                        .contentShape(Rectangle())
                        .gesture(dateGesture(for: date))
                    } else {
                        Color.clear.frame(height: 30)
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

    private var weekView: some View {
        VStack(spacing: 4) {
            ForEach(weekDays(containing: currentDate), id: \.self) { date in
                weekDayRow(date)
                    .gesture(dateGesture(for: date))

                if date != weekDays(containing: currentDate).last {
                    Divider()
                }
            }
        }
    }

    private func weekDayRow(_ date: Date) -> some View {
        let dayEvents = events(on: date)
        return HStack(alignment: .top, spacing: 10) {
            VStack(spacing: 2) {
                Text(date.formatted(.dateTime.weekday(.abbreviated)))
                    .font(.caption2.bold())
                    .foregroundStyle(.tertiary)
                Text("\(calendar.component(.day, from: date))")
                    .font(.subheadline.weight(calendar.isDateInToday(date) ? .bold : .medium))
                    .foregroundStyle(calendar.isDateInToday(date) ? .white : .primary)
                    .frame(width: 26, height: 26)
                    .background(calendar.isDateInToday(date) ? Color("AccentColor") : Color.clear, in: Circle())
            }
            .frame(width: 40)

            if dayEvents.isEmpty {
                Text("No events")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.top, 6)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(dayEvents.prefix(3)) { event in
                        HStack(spacing: 6) {
                            Circle().fill(event.category.color).frame(width: 6, height: 6)
                            Text(event.label)
                                .font(.caption.weight(.medium))
                                .lineLimit(1)
                        }
                    }
                    if dayEvents.count > 3 {
                        Text("+\(dayEvents.count - 3) more")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.top, 2)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }

    // MARK: - Day view

    private var dayView: some View {
        let dayEvents = events(on: currentDate)
        return VStack(alignment: .leading, spacing: 4) {
            if dayEvents.isEmpty {
                Text("No events scheduled.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 24)
            } else {
                ForEach(Array(dayEvents.enumerated()), id: \.element.id) { index, event in
                    CalendarEventRow(event: event)
                    if index < dayEvents.count - 1 {
                        Divider()
                    }
                }
            }
        }
    }

    // MARK: - Year view

    private func monthsInYear(_ date: Date) -> [Date] {
        guard let yearStart = calendar.date(from: calendar.dateComponents([.year], from: date)) else { return [] }
        return (0..<12).compactMap { calendar.date(byAdding: .month, value: $0, to: yearStart) }
    }

    private func events(inMonth monthDate: Date) -> [CalendarEventItem] {
        events.filter { calendar.isDate($0.date, equalTo: monthDate, toGranularity: .month) }
    }

    private var yearView: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 10) {
            ForEach(monthsInYear(currentDate), id: \.self) { monthDate in
                Button {
                    currentDate = monthDate
                    viewMode = .month
                } label: {
                    yearMonthTile(monthDate)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func yearMonthTile(_ monthDate: Date) -> some View {
        let monthEvents = events(inMonth: monthDate)
        let categories = Set(monthEvents.map(\.category)).sorted { $0.rawValue < $1.rawValue }
        return VStack(spacing: 6) {
            Text(monthDate.formatted(.dateTime.month(.abbreviated)))
                .font(.caption.bold())
                .foregroundStyle(calendar.isDate(monthDate, equalTo: Date(), toGranularity: .month) ? Color("AccentColor") : .primary)

            HStack(spacing: 3) {
                ForEach(categories.prefix(4), id: \.self) { category in
                    Circle().fill(category.color).frame(width: 5, height: 5)
                }
            }
            .frame(height: 5)

            Text(monthEvents.isEmpty ? " " : "\(monthEvents.count)")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color(.tertiarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Shared

    private var legend: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 6) {
            ForEach(CalendarCategory.allCases, id: \.self) { category in
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
        case .production: return .purple
        case .social: return .yellow
        case .performance: return Color("AccentColor")
        case .logistics: return .orange
        case .pr: return .pink
        case .reminder: return .teal
        }
    }
}
