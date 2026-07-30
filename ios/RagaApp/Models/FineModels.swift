import SwiftUI

enum FineStatus: String, Codable, CaseIterable {
    case unpaid = "UNPAID"
    case paid = "PAID"
    case waived = "WAIVED"

    var label: String {
        switch self {
        case .unpaid: return "Unpaid"
        case .paid: return "Paid"
        case .waived: return "Waived"
        }
    }

    var color: Color {
        switch self {
        case .paid: return .green
        case .unpaid: return .orange
        case .waived: return .gray
        }
    }
}

struct FineItem: Codable, Identifiable {
    let id: String
    let userId: String
    let amountCents: Int
    let reason: String
    let status: FineStatus
    let issuedAt: Date
    let paidAt: Date?
    let dueDate: Date?
    let user: AppUser
    let issuedBy: AppUser
}
