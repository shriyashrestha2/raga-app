import Foundation

// MARK: - Props & Costumes
//
// Extends APIClient (defined in APIClient.swift) rather than modifying it,
// per this subsystem's file-ownership constraints. Uses the same generic
// get/post/patch/delete verbs and x-user-id auth convention as the rest of
// the client.
extension APIClient {
    func fetchPropsCostumes(userId: String) async throws -> [PropCostumeItemModel] {
        try await get("props-costumes", userId: userId)
    }

    func fetchPropsCostumesBudget(userId: String) async throws -> PropsCostumesBudget {
        try await get("props-costumes/budget", userId: userId)
    }

    @discardableResult
    func createPropCostumeItem(name: String, category: PropCostumeCategoryType, userId: String) async throws -> PropCostumeItemModel {
        try await post("props-costumes", body: ["name": name, "category": category.rawValue], userId: userId)
    }

    @discardableResult
    func updatePropCostumeItem(id: String, status: PropCostumeStatusType, userId: String) async throws -> PropCostumeItemModel {
        try await patch("props-costumes/\(id)", body: ["status": status.rawValue], userId: userId)
    }

    @discardableResult
    func assignPropCostume(itemId: String, targetUserId: String, size: String?, task: String?, userId: String) async throws -> PropCostumeAssignmentModel {
        var body: [String: Any] = ["userId": targetUserId]
        if let size { body["size"] = size }
        if let task { body["task"] = task }
        return try await post("props-costumes/\(itemId)/assignments", body: body, userId: userId)
    }
}
