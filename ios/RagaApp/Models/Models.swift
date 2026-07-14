import Foundation

enum Role: String, Codable, CaseIterable {
    case captain = "CAPTAIN"
    case dancer = "DANCER"
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

    var label: String {
        switch self {
        case .finance: return "Finance"
        case .practice: return "Practice / Captains"
        case .production: return "Production"
        case .social: return "Social"
        case .performance: return "Performance"
        }
    }
}

struct AppUser: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let initials: String
    let role: Role
}

struct UpdateItem: Codable, Identifiable {
    let id: String
    let tag: UpdateTag
    let content: String
    let pinned: Bool
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
}
