import SwiftUI

// MARK: - Comp Applications (Captain/Logistics-only competition-application tracker)

enum CompApplicationStatusType: String, Codable, CaseIterable {
    case notStarted = "NOT_STARTED"
    case inProgress = "IN_PROGRESS"
    case submitted = "SUBMITTED"
    case accepted = "ACCEPTED"
    case rejected = "REJECTED"

    var label: String {
        switch self {
        case .notStarted: return "Not Started"
        case .inProgress: return "In Progress"
        case .submitted: return "Submitted"
        case .accepted: return "Accepted"
        case .rejected: return "Rejected"
        }
    }

    var color: Color {
        switch self {
        case .notStarted: return .gray
        case .inProgress: return .blue
        case .submitted: return .orange
        case .accepted: return .green
        case .rejected: return .red
        }
    }
}

struct CompApplicationItem: Codable, Identifiable {
    let id: String
    let competitionName: String
    let deadline: Date
    let status: CompApplicationStatusType
    let packetUrl: String?
    let notes: String?
    let assignedTo: AppUser?
    let createdBy: AppUser
}
