import Foundation

/// Mirrors backend/src/routes/funds.ts's response shape (Fund + included
/// `createdBy` relation). Fundraising totals are team-wide, not per-user, so
/// every role can read the full list — only logging a new fund is gated
/// (see Capabilities.fundraising).
struct FundItem: Codable, Identifiable {
    let id: String
    let amountCents: Int
    let source: String
    let dateAdded: Date
    let createdBy: AppUser
}
