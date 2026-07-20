import Foundation

/// Mirrors backend/src/routes/fineSchedule.ts's response shape. Most
/// offenses have a fixed `amountCents`; a few store a plain-text
/// `description` of the rule instead and leave `amountCents` nil — `isVariable`
/// is the client-side signal to leave the new-fine Amount field blank rather
/// than auto-filling it.
struct FineScheduleEntry: Codable, Identifiable {
    let id: String
    let offense: String
    let amountCents: Int?
    let description: String?
    let order: Int

    var isVariable: Bool { amountCents == nil }
}
