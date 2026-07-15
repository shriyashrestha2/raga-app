import Foundation

/// Mirrors the backend's singleton `TeamInfo` row (backend/prisma/schema.prisma).
/// There is exactly one of these, seeded once — see backend/prisma/seed.ts.
struct TeamInfoModel: Codable {
    let id: String
    let teamName: String
    let season: String
    let description: String?
}
