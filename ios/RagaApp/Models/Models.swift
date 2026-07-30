import Foundation
import UIKit

enum Role: String, Codable, CaseIterable {
    case captain = "CAPTAIN"
    case finance = "FINANCE"
    case production = "PRODUCTION"
    case logistics = "LOGISTICS"
    case pr = "PR"
    case returner = "RETURNER"
    case newbie = "NEWBIE"

    var label: String {
        switch self {
        case .captain: return "Captain"
        case .finance: return "Finance"
        case .production: return "Production"
        case .logistics: return "Logistics"
        case .pr: return "PR Chair"
        case .returner: return "Returner"
        case .newbie: return "Newbie"
        }
    }

    var symbol: String {
        switch self {
        case .captain: return "shield.fill"
        case .finance: return "dollarsign.circle.fill"
        case .production: return "video.fill"
        case .logistics: return "shippingbox.fill"
        case .pr: return "megaphone.fill"
        case .returner: return "person.fill"
        case .newbie: return "person.fill.questionmark"
        }
    }

    /// Board positions whose role badge shows next to their name in Chat —
    /// mirrors backend/src/permissions.ts's isBoardRole (Captain plus the
    /// four board chairs; Returner/Newbie are the only non-board roles).
    var isBoardRole: Bool {
        self != .returner && self != .newbie
    }
}

enum UpdateTag: String, Codable, CaseIterable {
    case announcement = "ANNOUNCEMENT"
    case costumeLogistics = "COSTUME_LOGISTICS"
    case choreoNotes = "CHOREO_NOTES"
    case finance = "FINANCE"

    var label: String {
        switch self {
        case .announcement: return "Announcement"
        case .costumeLogistics: return "Costume & Logistics"
        case .choreoNotes: return "Choreo Notes"
        case .finance: return "Finance"
        }
    }

    /// System-generated only (fund logged, fine issued/reminder) — excluded
    /// from the compose picker in NewUpdateSheet since the server's
    /// createUpdateSchema doesn't accept it as a user-postable tag either.
    static let userCreatable: [UpdateTag] = [.announcement, .costumeLogistics, .choreoNotes]
}

enum RsvpResponse: String, Codable {
    case yes = "YES"
    case no = "NO"
}

enum CalendarCategory: String, Codable, CaseIterable {
    case finance = "FINANCE"
    case practice = "PRACTICE"
    case captains = "CAPTAINS"
    case production = "PRODUCTION"
    case social = "SOCIAL"
    case logistics = "LOGISTICS"

    var label: String {
        switch self {
        case .finance: return "Finance"
        case .practice: return "Practice"
        case .captains: return "Captains"
        case .production: return "Production"
        case .social: return "PR"
        case .logistics: return "Logistics"
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
    /// Board roles can view every record in the domain; everyone else can
    /// still see their own quota/fine (fundraising has no "own record" for
    /// non-board members to fall back to). Only canManageAny gates create/edit.
    struct ViewManageCapability: Codable { let canViewAny: Bool; let canManageAny: Bool }
    struct CompetitionDashboardCapability: Codable { let editableSection: String?; let canViewSchedule: Bool }
    struct TeamInfoCapability: Codable { let canEdit: Bool }
    struct RemindersCapability: Codable { let canCreate: Bool; let lockedCategory: CalendarCategory? }
    struct NotificationsCapability: Codable { let canDeleteAny: Bool }
    struct ChatCapability: Codable { let canPinAny: Bool }

    let calendar: CalendarCapability
    let attendance: AttendanceCapability
    let announcements: AnnouncementsCapability
    let videos: VideosCapability
    let practicePlanner: AccessOnly
    let choreoReminders: AccessOnly
    let propsCostumes: PropsCostumesCapability
    let fines: ViewManageCapability
    let quotas: ViewManageCapability
    let fundraising: ViewManageCapability
    let fineSchedule: ViewManageCapability
    let compApplications: AccessOnly
    let competitionDashboard: CompetitionDashboardCapability
    let teamInfo: TeamInfoCapability
    let roleManagement: AccessOnly
    let reminders: RemindersCapability
    let notifications: NotificationsCapability
    let chat: ChatCapability
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
    /// Roles allowed to see this update; empty means visible to everyone.
    let visibleToRoles: [Role]
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
    let pinned: Bool
    let pinLabel: String?
    let uploadedBy: AppUser

    /// `url` is a relative path served by our own backend (e.g.
    /// `/uploads/videos/<id>.mp4`), not an external link — resolve it
    /// against the API's base URL for in-app playback.
    var resolvedURL: URL? {
        URL(string: url, relativeTo: APIClient.shared.baseURL)?.absoluteURL
    }
}

struct CalendarEventItem: Codable, Identifiable {
    let id: String
    let date: Date
    let category: CalendarCategory
    let label: String
    let canEdit: Bool
    /// Roles allowed to see this event; empty means visible to everyone.
    let visibleToRoles: [Role]
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

// MARK: - Shared team reminders (Roundup tab, all roles see the same list)

enum ReminderKind: String, Codable, CaseIterable {
    case rsvp = "RSVP"
    case task = "TASK"

    var label: String {
        switch self {
        case .rsvp: return "RSVP"
        case .task: return "Task"
        }
    }
}

struct ReminderItem: Codable, Identifiable {
    let id: String
    let title: String
    let description: String?
    let date: Date
    let category: CalendarCategory
    let type: ReminderKind
    let createdBy: AppUser
    let rsvpYes: Int
    let rsvpNo: Int
    let myRsvp: RsvpResponse?
    let doneCount: Int
    let doneByMe: Bool
}

// MARK: - Team chat (Chat tab, single flat channel, every role participates)

struct ChatReactionSummary: Codable, Identifiable, Hashable {
    var id: String { emoji }
    let emoji: String
    let count: Int
    let reactedByMe: Bool
}

enum ChatAttachmentKind: String, Codable {
    case image = "IMAGE"
    case file = "FILE"
}

struct ChatAttachmentItem: Codable, Identifiable {
    let id: String
    let kind: ChatAttachmentKind
    let url: String
    let fileName: String
    let mimeType: String
    let fileSizeBytes: Int

    /// `url` is a relative path served by our own backend (e.g.
    /// `/uploads/chat/<id>.png`), not an external link — resolve it against
    /// the API's base URL, matching VideoItem.resolvedURL's pattern.
    var resolvedURL: URL? {
        URL(string: url, relativeTo: APIClient.shared.baseURL)?.absoluteURL
    }

    var formattedFileSize: String {
        ByteCountFormatter.string(fromByteCount: Int64(fileSizeBytes), countStyle: .file)
    }
}

struct ChatMessageItem: Codable, Identifiable {
    let id: String
    let content: String
    let pinned: Bool
    let createdAt: Date
    let author: AppUser
    let attachments: [ChatAttachmentItem]
    let reactions: [ChatReactionSummary]
}

/// A photo or file the user picked but hasn't sent yet — built client-side
/// from PhotosPicker/fileImporter output, never decoded from the server
/// (contrast with ChatAttachmentItem, which is what a sent message reports
/// back). Held in-memory only until send() turns it into multipart form
/// data.
struct ChatOutgoingAttachment: Identifiable {
    let id = UUID()
    let fileName: String
    let mimeType: String
    let data: Data
    /// Only set for images — lets the composer preview show a thumbnail
    /// without re-decoding `data` on every redraw.
    let previewImage: UIImage?
}
