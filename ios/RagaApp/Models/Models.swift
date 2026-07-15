import Foundation

enum Role: String, Codable, CaseIterable {
    case captain = "CAPTAIN"
    case finance = "FINANCE"
    case production = "PRODUCTION"
    case logistics = "LOGISTICS"
    case dancer = "DANCER"
    case newbie = "NEWBIE"

    var label: String {
        switch self {
        case .captain: return "Captain"
        case .finance: return "Finance"
        case .production: return "Production"
        case .logistics: return "Logistics"
        case .dancer: return "Dancer"
        case .newbie: return "Newbie"
        }
    }

    var symbol: String {
        switch self {
        case .captain: return "shield.fill"
        case .finance: return "dollarsign.circle.fill"
        case .production: return "video.fill"
        case .logistics: return "shippingbox.fill"
        case .dancer: return "person.fill"
        case .newbie: return "person.fill.questionmark"
        }
    }
}

enum UpdateTag: String, Codable {
    case announcement = "ANNOUNCEMENT"
    case costumeLogistics = "COSTUME_LOGISTICS"
    case choreoNotes = "CHOREO_NOTES"

    var label: String {
        switch self {
        case .announcement: return "Announcement"
        case .costumeLogistics: return "Costume & Logistics"
        case .choreoNotes: return "Choreo Notes"
        }
    }
}

enum RsvpResponse: String, Codable {
    case yes = "YES"
    case no = "NO"
}

enum CalendarCategory: String, Codable, CaseIterable {
    case finance = "FINANCE"
    case practice = "PRACTICE"
    case production = "PRODUCTION"
    case social = "SOCIAL"
    case performance = "PERFORMANCE"
    case logistics = "LOGISTICS"
    case reminder = "REMINDER"

    var label: String {
        switch self {
        case .finance: return "Finance"
        case .practice: return "Practice / Captains"
        case .production: return "Production"
        case .social: return "Social"
        case .performance: return "Performance"
        case .logistics: return "Logistics"
        case .reminder: return "Reminder"
        }
    }
}

struct AppUser: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let initials: String
    let role: Role
    let email: String?
    let phone: String?
    let year: String?
    let major: String?
    let bio: String?
    let emergencyContactName: String?
    let emergencyContactPhone: String?
}

// Mirrors backend/src/permissions.ts's Capabilities shape field-for-field.
// Coarse, role-only — used purely for nav/UI-affordance decisions (show/hide
// a menu row). Per-item mutation gating uses server-embedded `canEdit` flags
// on individual records instead, so the client never re-derives contextual
// permission logic.
struct Capabilities: Codable {
    struct CalendarCapability: Codable { let canEditAny: Bool; let editableCategory: Role? }
    struct AttendanceCapability: Codable { let canEditAny: Bool; let editableCategory: Role? }
    struct AnnouncementsCapability: Codable { let canPostTeamWide: Bool; let ownChannelRole: Role? }
    struct VideosCapability: Codable { let canUpload: Bool }
    struct AccessOnly: Codable { let canAccess: Bool }
    struct PropsCostumesCapability: Codable { let mode: String }
    struct ManageAnyCapability: Codable { let canManageAny: Bool }
    struct CompetitionDashboardCapability: Codable { let editableSection: String?; let canViewSchedule: Bool }
    struct TeamInfoCapability: Codable { let canEdit: Bool }

    let calendar: CalendarCapability
    let attendance: AttendanceCapability
    let announcements: AnnouncementsCapability
    let videos: VideosCapability
    let practicePlanner: AccessOnly
    let choreoReminders: AccessOnly
    let propsCostumes: PropsCostumesCapability
    let fines: ManageAnyCapability
    let quotas: ManageAnyCapability
    let compApplications: AccessOnly
    let competitionDashboard: CompetitionDashboardCapability
    let teamInfo: TeamInfoCapability
    let roleManagement: AccessOnly
}

struct MeResponse: Codable {
    let id: String
    let name: String
    let role: Role
    let capabilities: Capabilities
}

struct UpdateItem: Codable, Identifiable {
    let id: String
    let tag: UpdateTag
    let content: String
    let pinned: Bool
    let audienceRole: Role?
    let createdAt: Date
    let author: AppUser
}

struct RsvpMine: Codable {
    let response: RsvpResponse
    let reason: String?
}

struct RsvpDetail: Codable, Identifiable {
    var id: String { name + response.rawValue }
    let name: String
    let response: RsvpResponse
    let reason: String?
}

struct PracticeItem: Codable, Identifiable {
    let id: String
    let date: Date
    let location: String
    let focus: String
    let reminder: String?
    let rsvpYes: Int
    let rsvpNo: Int
    let myRsvp: RsvpMine?
    let detail: [RsvpDetail]?
}

struct VideoItem: Codable, Identifiable {
    let id: String
    let title: String
    let set: String
    let competition: String?
    let date: Date
    let url: String
    let thumbnail: String?
    let duration: String?
    let uploadedBy: AppUser
}

struct CalendarEventItem: Codable, Identifiable {
    let id: String
    let date: Date
    let category: CalendarCategory
    let label: String
    let canEdit: Bool
}

// MARK: - Choreo/formation reminders (Captain-dashboard-only widgets)

enum ChoreoReminderKind: String, Codable {
    case formation = "FORMATION"
    case choreoNote = "CHOREO_NOTE"

    var icon: String {
        switch self {
        case .formation: return "figure.dance"
        case .choreoNote: return "note.text"
        }
    }
}

struct ChoreoReminderItem: Codable, Identifiable {
    let id: String
    let label: String
    let kind: ChoreoReminderKind
    let resolved: Bool
}

// MARK: - Practice Planner (Captain-only agenda/timeline tool)

struct PracticeAgendaItemModel: Codable, Identifiable {
    let id: String
    let order: Int
    let startOffsetMin: Int
    let durationMin: Int
    let label: String
    let notes: String?
}

struct PracticePlanItem: Codable, Identifiable {
    let id: String
    let practiceId: String?
    let title: String
    let date: Date
    let agendaItems: [PracticeAgendaItemModel]
}

// MARK: - Real attendance (distinct from Rsvp intent)

enum AttendanceStatus: String, Codable, CaseIterable {
    case present = "PRESENT"
    case absent = "ABSENT"
    case late = "LATE"
    case excused = "EXCUSED"

    var label: String {
        switch self {
        case .present: return "Present"
        case .absent: return "Absent"
        case .late: return "Late"
        case .excused: return "Excused"
        }
    }
}

struct AttendanceRecord: Codable, Identifiable {
    let id: String
    let userId: String
    let status: AttendanceStatus
    let notes: String?
    let user: AppUser
}

struct AttendanceForEvent: Codable {
    let canEdit: Bool
    let records: [AttendanceRecord]
}

// MARK: - Personal reminders (Roundup tab, all roles)

struct ReminderItem: Codable, Identifiable {
    let id: String
    let topicId: String
    let title: String
    let description: String?
    let date: Date
    let addedToCalendar: Bool
}

struct ReminderTopic: Codable, Identifiable {
    let id: String
    let name: String
    let reminders: [ReminderItem]
}
