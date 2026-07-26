import SwiftUI

/// Unifies the two backend-distinct feeds — Reminder (task/RSVP) and Update
/// (announcement/costume/choreo) — into one client-side feed for display,
/// matching the Figma prototype's single `Notification` model. The backend
/// keeps them as separate tables/endpoints; this is purely a UI-layer merge.
enum NotificationFeedItem: Identifiable {
    case reminder(ReminderItem)
    case announcement(UpdateItem)

    var id: String {
        switch self {
        case .reminder(let r): return "reminder-\(r.id)"
        case .announcement(let u): return "update-\(u.id)"
        }
    }

    var displayCategory: CalendarCategory {
        switch self {
        case .reminder(let r): return r.category
        case .announcement(let u):
            switch u.tag {
            case .announcement: return .captains
            case .costumeLogistics: return .production
            case .choreoNotes: return .captains
            }
        }
    }

    var typeLabel: String {
        switch self {
        case .reminder(let r): return r.type.label
        case .announcement(let u): return u.tag.label
        }
    }

    /// Reminders have a distinct title separate from their description; an
    /// Update is just one block of `content`, so its content doubles as the
    /// card's bold headline (with the type pill covering the "what kind" role).
    var title: String {
        switch self {
        case .reminder(let r): return r.title
        case .announcement(let u): return u.content
        }
    }

    var bodyText: String? {
        switch self {
        case .reminder(let r): return r.description
        case .announcement: return nil
        }
    }

    var authorName: String {
        switch self {
        case .reminder(let r): return r.createdBy.name
        case .announcement(let u): return u.author.name
        }
    }

    var authorInitials: String {
        switch self {
        case .reminder(let r): return r.createdBy.initials
        case .announcement(let u): return u.author.initials
        }
    }

    var pinned: Bool {
        if case .announcement(let u) = self { return u.pinned }
        return false
    }

    /// Underlying instant used for both display ("Oct 5") and "Coming Up"
    /// scoring — a reminder's due date, or an announcement's post time.
    var sortDate: Date {
        switch self {
        case .reminder(let r): return r.date
        case .announcement(let u): return u.createdAt
        }
    }

    var dateLabel: String {
        sortDate.formatted(.dateTime.month(.abbreviated).day())
    }
}
