import SwiftUI

/// A single calendar event row: time, category dot, label + category name.
/// Shared between the day-view list and the date drill-down sheet.
struct CalendarEventRow: View {
    let event: CalendarEventItem

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text(event.date.formatted(date: .omitted, time: .shortened))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 64, alignment: .leading)

            Circle()
                .fill(event.category.color)
                .frame(width: 8, height: 8)
                .padding(.top, 4)

            VStack(alignment: .leading, spacing: 2) {
                Text(event.label)
                    .font(.subheadline.weight(.medium))
                Text(event.category.label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }
}

/// Chronological breakdown of every event on a tapped date.
struct CalendarDayDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    let date: Date
    let events: [CalendarEventItem]

    private var sortedEvents: [CalendarEventItem] {
        events.sorted { $0.date < $1.date }
    }

    var body: some View {
        NavigationStack {
            Group {
                if sortedEvents.isEmpty {
                    EmptyStateView(
                        icon: "calendar",
                        title: "No events",
                        message: "Nothing scheduled for this day."
                    )
                    .padding(.top, 60)
                } else {
                    List(sortedEvents) { event in
                        CalendarEventRow(event: event)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle(date.formatted(.dateTime.weekday(.wide).month(.wide).day()))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
