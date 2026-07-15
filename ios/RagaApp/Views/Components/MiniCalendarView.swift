import SwiftUI

struct MiniCalendarView: View {
    let events: [CalendarEventItem]

    @State private var visibleMonth: Date = {
        var components = DateComponents()
        components.year = 2026
        components.month = 10
        components.day = 1
        return Calendar.current.date(from: components) ?? Date()
    }()

    private let calendar = Calendar.current
    private let weekdaySymbols = ["S", "M", "T", "W", "T", "F", "S"]

    private var monthTitle: String {
        visibleMonth.formatted(.dateTime.month(.wide).year())
    }

    private var days: [Date?] {
        guard let range = calendar.range(of: .day, in: .month, for: visibleMonth),
              let firstOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: visibleMonth))
        else { return [] }

        let firstWeekday = calendar.component(.weekday, from: firstOfMonth) - 1 // 0 = Sunday
        var cells: [Date?] = Array(repeating: nil, count: firstWeekday)
        cells += range.compactMap { day in
            calendar.date(byAdding: .day, value: day - 1, to: firstOfMonth)
        }
        while cells.count % 7 != 0 { cells.append(nil) }
        return cells
    }

    private func events(on date: Date) -> [CalendarEventItem] {
        events.filter { calendar.isDate($0.date, inSameDayAs: date) }
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text(monthTitle)
                    .font(.subheadline.bold())
                Spacer()
                HStack(spacing: 4) {
                    Button { shiftMonth(-1) } label: {
                        Image(systemName: "chevron.left")
                    }
                    Button { shiftMonth(1) } label: {
                        Image(systemName: "chevron.right")
                    }
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.circle)
                .controlSize(.mini)
            }

            HStack {
                ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .font(.caption2.bold())
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 6) {
                ForEach(Array(days.enumerated()), id: \.offset) { _, date in
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
                    } else {
                        Color.clear.frame(height: 30)
                    }
                }
            }

            Divider()

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
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(Color(.separator), lineWidth: 0.5))
    }

    private func shiftMonth(_ delta: Int) {
        if let newMonth = calendar.date(byAdding: .month, value: delta, to: visibleMonth) {
            visibleMonth = newMonth
        }
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
        }
    }
}
