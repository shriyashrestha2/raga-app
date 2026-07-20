import Foundation

/// Mirrors backend/src/routes/quotas.ts's response shape (Quota + included
/// `user` relation). Managers (Captain/Finance, per Capabilities.quotas)
/// see every member's quota; everyone else only ever gets their own back
/// from GET /quotas, since the server force-filters non-managers.
struct QuotaItem: Codable, Identifiable {
    let id: String
    let userId: String
    let label: String
    let unit: String
    let targetValue: Double
    /// Derived server-side from the sum of `contributions` — never set
    /// directly (see QuotaContribution).
    let currentValue: Double
    let dueDate: Date?
    let user: AppUser
    let contributions: [QuotaContribution]
}

/// One itemized entry toward a quota (e.g. "Bake Sale — $45"), newest first.
struct QuotaContribution: Codable, Identifiable {
    let id: String
    let event: String
    let amount: Double
    let createdAt: Date
}
